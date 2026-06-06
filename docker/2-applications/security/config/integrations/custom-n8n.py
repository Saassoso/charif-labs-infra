#!/var/ossec/framework/python/bin/python3
import sys, json, urllib.request, time

LOG = "/var/ossec/logs/integrations.log"

def log(msg):
    with open(LOG, "a") as f:
        f.write(f"custom-n8n: {msg}\n")

try:
    alert_file  = sys.argv[1]
    webhook_url = sys.argv[3]

    # Retry until file is written (race condition guard)
    content = ""
    for i in range(10):
        with open(alert_file) as f:
            content = f.read().strip()
        if content:
            break
        time.sleep(0.2)

    if not content:
        log("ERROR: alert file empty after 2s")
        sys.exit(1)

    # Try JSON first, then fall back to shell key=value format
    try:
        alert_data = json.loads(content)
        log("parsed as JSON")
    except json.JSONDecodeError:
        # Parse: key='value' per line
        alert_data = {}
        for line in content.splitlines():
            if "=" in line:
                key, _, val = line.partition("=")
                alert_data[key.strip()] = val.strip().strip("'")
        log(f"parsed as shell-format, keys={list(alert_data.keys())}")

    payload = json.dumps(alert_data).encode()
    req = urllib.request.Request(
        webhook_url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "X-Wazuh-Token": "secure-wazuh-key-2026"
        }
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        log(f"SUCCESS: HTTP {resp.status}")

except Exception as e:
    log(f"ERROR: {type(e).__name__}: {e}")
    sys.exit(1)