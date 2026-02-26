#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <list>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <sstream>
#include <functional>
#include <netinet/in.h>
#include <unistd.h>
#include <algorithm>

struct Tuple {
    std::string value;
};

class TupleSpace {
private:
    std::map<std::string, std::list<Tuple>> space;
    std::mutex mtx;
    std::condition_variable cv;
    std::map<int, std::function<std::string(std::string)>> services;

public:
    TupleSpace() {
        services[1] = []( std::string v ) { 
                            // in, in, out gravar dados, ação
            std::transform( v.begin(), v.end(), v.begin(), ::toupper ); 
            return v; 
        }; //retorna a string com as letras maiusculas
        services[2] = []( std::string v ) { 
            std::reverse( v.begin(), v.end() ); 
            return v; 
        }; //retorna a string de trás para frente
        services[3] = []( std::string v ) { 
            return std::to_string( v.length() ); 
        }; //retorna o tamanho da string
    }
    // escrita
    void wr( std::string k, std::string v ) {
        std::lock_guard<std::mutex> lock( mtx ); // bloqueia outras threads e libera ao sair do escopo
        space[k].push_back({v});
        cv.notify_all(); // Notifica threads bloqueadas 
    }
    // leitura
    std::string rd( std::string k ) {
        std::unique_lock<std::mutex> lock( mtx ); // bloqueia outras threads
        cv.wait( lock, [&] { return !space[k].empty(); } ); // dorme até ser notificado - 
                                                            // se for sua chave - tranca o mutex e realiza a operação 
                                                            // libera ao sair do escopo
                                                            // Bloqueio sem busy-waiting( consumir CPU desnecessariamente enquanto espera )
        return space[k].front().value;
    }
    // leitura e remoção
    std::string in( std::string k ) {
        std::unique_lock<std::mutex> lock(mtx);
        cv.wait(lock, [&] { return !space[k].empty(); }); 
        std::string val = space[k].front().value;
        space[k].pop_front();
        return val;
    }
    //execute
    std::string ex( std::string k_in, std::string k_out, int svc_id ) {

        std::unique_lock<std::mutex> lock(mtx);
        
        // 1. Valida serviço ANTES de remover a tupla 
        if ( services.find(svc_id ) == services.end() ) {
            return "NO-SERVICE";
        }

        // 2. Aguarda a tupla de entrada 
        cv.wait( lock, [&] { return !space[k_in].empty(); });

        std::string v_in = space[k_in].front().value;
        space[k_in].pop_front(); // Remove como no IN 

        // 3. Executa o serviço e insere o resultado 
        auto func = services[svc_id];
        lock.unlock(); // Destrava para não bloquear o servidor durante o processamento 
                       // desbloqueio manual, sem esperar sair do escopo  
        
        std::string v_out = func(v_in);
        wr( k_out, v_out ); 
        return "OK";
    }
};

// Função auxiliar para ler uma linha completa do socket 
std::string read_line( int sock  ) {
    std::string line;
    char ch;
    while ( recv( sock, &ch, 1, 0 ) > 0) {
        if ( ch == '\n' ) break;
        if ( ch != '\r' ) line += ch;
    }
    return line;
}

void handle_client( int client_sock, TupleSpace& ts ) {
    while ( true ) {
        std::string input = read_line( client_sock );
        if (input.empty()) break;

        std::stringstream ss(input);
        std::string cmd, k1, k2, v;
        int svc_id;

        ss >> cmd;
        if (cmd == "WR") {
            ss >> k1;
            std::getline(ss >> std::ws, v); // Lê o resto da linha como valor
            ts.wr(k1, v);
            send(client_sock, "OK\n", 3, 0); 
        } else if (cmd == "RD") {
            ss >> k1;
            std::string res = ts.rd(k1);
            std::string msg = "OK " + res + "\n"; 
            send(client_sock, msg.c_str(), msg.size(), 0);
        } else if (cmd == "IN") {
            ss >> k1;
            std::string res = ts.in(k1);
            std::string msg = "OK " + res + "\n"; 
            send(client_sock, msg.c_str(), msg.size(), 0);
        } else if (cmd == "EX") {
            if (ss >> k1 >> k2 >> svc_id) {
                std::string res = ts.ex(k1, k2, svc_id);
                std::string msg = res + "\n";
                send(client_sock, msg.c_str(), msg.size(), 0);
            }
        } else {
            send(client_sock, "ERROR\n", 6, 0); 
        }
    }
    close(client_sock);
}

int main() {

    int server_fd = socket( AF_INET, SOCK_STREAM, 0 );
    if ( server_fd == -1 ) return 1;

    // Porta sugerida 
    sockaddr_in addr{ AF_INET, htons(54321), INADDR_ANY };
    
    // Evita erro de "Address already in use" ao reiniciar
    int opt = 1;
    setsockopt( server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt) );

    if ( bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0 ) return 1;
    listen( server_fd, 10 );
    
    TupleSpace ts;
    std::cout << "Servidor Linda C++ rodando na porta 54321..." << std::endl;

    while (true) {
        int client_sock = accept( server_fd, nullptr, nullptr );
        if (client_sock >= 0) {
            std::thread( handle_client, client_sock, std::ref(ts) ).detach();
        }
    }
    return 0;
    
}
