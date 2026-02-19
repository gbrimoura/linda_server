# Servidor de Espaço de Tuplas Linda — Elixir

O servidor implementa um espaço de tuplas concorrente com suporte às seguintes operações:

* WR — escrita de tupla
* RD — leitura não destrutiva (bloqueante)
* IN — leitura destrutiva (bloqueante)
* EX — execução de serviço sobre uma tupla

Cada tupla possui o formato:

```
(chave: string, valor: string)
```

O servidor suporta múltiplos clientes simultaneamente via TCP.


# Porta utilizada

```
54321
```

# Serviços Implementados

Tabela de serviços disponíveis:

| svc_id | descrição                 | exemplo       |
| ------ | ------------------------- | ------------- |
| 1      | converte para maiúsculas  | "abc" → "ABC" |
| 2      | inverte a string          | "abc" → "cba" |
| 3      | retorna tamanho da string | "abc" → "3"   |

Serviços inexistentes retornam:

```
NO-SERVICE
```

---

# Protocolo TCP

Comandos aceitos:

```
WR chave valor
RD chave
IN chave
EX chave_entrada chave_saida svc_id
```

Respostas:

```
OK
OK valor
NO-SERVICE
ERROR
```

---

# Compilação e Execução


## Compilar

Dentro da pasta do projeto:

```
mix deps.get
mix compile
```

---

## Executar o servidor

```
mix run --no-halt
```

Saída esperada:

```
Linda Server listening on port 54321
```

---


# Exemplos de uso manual (telnet)

Conectar:

```
telnet 127.0.0.1 54321
```

Enviar comandos:

```
WR chave1 valor1
OK

RD chave1
OK valor1

IN chave1
OK valor1
```


---
