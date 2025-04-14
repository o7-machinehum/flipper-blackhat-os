$1 == "BSS" {
    MAC = $2
    wifi[MAC]["enc"] = "Open"   # default encryption
}
$1 == "SSID:" {
    wifi[MAC]["SSID"] = $2
}
$1 == "freq:" {
    wifi[MAC]["freq"] = $NF
}
$1 == "signal:" {
    wifi[MAC]["sig"] = $2 " " $3
}
$1 == "WPA:" {
    wifi[MAC]["enc"] = "WPA"
}
$1 == "WEP:" {
    wifi[MAC]["enc"] = "WEP"
}
$1 == "RSN:" {
    wifi[MAC]["enc"] = "WPA2"
}
END {
    printf "%s\t%s\n", "SSID", "Encryption"
    for (w in wifi) {
        printf "%s\t%s\n", wifi[w]["SSID"], wifi[w]["enc"]
    }
}

