defmodule LindaServer.TupleSpace do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{
      tuples: %{},
      waiters: %{},
      services: services()
    }, name: __MODULE__)
  end

  def wr(k, v), do: GenServer.call(__MODULE__, {:wr, k, v})
  def rd(k), do: GenServer.call(__MODULE__, {:rd, k}, :infinity)
  def in_op(k), do: GenServer.call(__MODULE__, {:in, k}, :infinity)
  def ex(k_in, k_out, svc), do: GenServer.call(__MODULE__, {:ex, k_in, k_out, svc}, :infinity)

  def init(state), do: {:ok, state}

  def handle_call({:wr, k, v}, _from, state) do
    queue = Map.get(state.tuples, k, :queue.new())
    new_queue = :queue.in(v, queue)

    state2 =
      %{state | tuples: Map.put(state.tuples, k, new_queue)}
      |> wake_waiters(k)

    {:reply, :ok, state2}
  end

  def handle_call({:rd, k}, from, state) do
    case peek(k, state) do
      {:ok, v} ->
        {:reply, {:ok, v}, state}

      :empty ->
        {:noreply, add_waiter(k, from, :rd, state)}
    end
  end

  def handle_call({:in, k}, from, state) do
    case pop(k, state) do
      {:ok, v, state2} ->
        {:reply, {:ok, v}, state2}

      :empty ->
        {:noreply, add_waiter(k, from, :in, state)}
    end
  end

  def handle_call({:ex, k_in, k_out, svc}, from, state) do
    case pop(k_in, state) do
      {:ok, v, state2} ->
        case Map.get(state.services, svc) do
          nil ->
            {:reply, :no_service, state2}

          func ->
            v_out = func.(v)

            queue = Map.get(state2.tuples, k_out, :queue.new())
            queue2 = :queue.in(v_out, queue)

            state3 =
              %{state2 | tuples: Map.put(state2.tuples, k_out, queue2)}
              |> wake_waiters(k_out)

            {:reply, :ok, state3}
        end

      :empty ->
        {:noreply, add_waiter(k_in, from, {:ex, k_out, svc}, state)}
    end
  end

  defp peek(k, state) do
    case Map.get(state.tuples, k) do
      nil -> :empty
      q ->
        case :queue.peek(q) do
          {:value, v} -> {:ok, v}
          :empty -> :empty
        end
    end
  end

  defp pop(k, state) do
    case Map.get(state.tuples, k) do
      nil -> :empty
      q ->
        case :queue.out(q) do
          {{:value, v}, q2} ->
            {:ok, v, %{state | tuples: Map.put(state.tuples, k, q2)}}

          {:empty, _} ->
            :empty
        end
    end
  end

  defp add_waiter(k, from, op, state) do
    list = Map.get(state.waiters, k, [])
    %{state | waiters: Map.put(state.waiters, k, list ++ [{from, op}])}
  end

  defp wake_waiters(state, k) do
    case Map.get(state.waiters, k, []) do
      [] -> state

      [{from, op} | rest] ->
        case pop(k, state) do
          {:ok, v, state2} ->
            state3 = %{state2 | waiters: Map.put(state2.waiters, k, rest)}

            case op do
              :rd ->
                GenServer.reply(from, {:ok, v})
                wake_waiters(state3, k)

              :in ->
                GenServer.reply(from, {:ok, v})
                wake_waiters(state3, k)

              {:ex, k_out, svc} ->
                case Map.get(state.services, svc) do
                  nil ->
                    GenServer.reply(from, :no_service)
                    wake_waiters(state3, k)

                  func ->
                    v_out = func.(v)
                    wr(k_out, v_out)
                    GenServer.reply(from, :ok)
                    wake_waiters(state3, k)
                end
            end

          :empty ->
            state
        end
    end
  end

  defp services do
    %{
      1 => &String.upcase/1,
      2 => &String.reverse/1,
      3 => fn v -> Integer.to_string(String.length(v)) end
    }
  end
end

