Provide your solution here:


## Problem 3: Diagnose Me Doctor

### Overview

A VM running only nginx as a load balancer is at 99% disk usage. Since the only service is nginx, the investigation is fairly focused.

---

### Step 1: Confirm and locate the disk usage

```bash
df -h
du -sh /* 2>/dev/null | sort -rh | head -20
du -sh /var/log/nginx/* | sort -rh
```

This tells you which partition is full and narrows down which directory is consuming the space.

---

### Possible Root Causes

**1. Nginx access/error logs have grown unbounded**

This is the most likely cause. Nginx logs every request by default with no rotation limit, and on a busy load balancer these can grow to tens of GBs quickly.

- Impact: Disk full causes nginx to fail writing logs, and depending on config may cause nginx itself to crash or refuse connections.
- Diagnosis: `ls -lh /var/log/nginx/`

- Recovery:

```bash
# truncate immediately to free space
truncate -s 0 /var/log/nginx/access.log
truncate -s 0 /var/log/nginx/error.log
# then force logrotate
logrotate -f /etc/logrotate.d/nginx
```
- Prevention: Configure `/etc/logrotate.d/nginx` with `daily`, `rotate 7`, `compress`, `missingok`, `notifempty`

---

**2. Logrotate is misconfigured or not running**

Even if logrotate is set up, it may not be rotating correctly — wrong schedule, missing postrotate to reopen nginx file handles, or the cron/timer is disabled.

- Impact: Same as above, logs accumulate silently.
- Diagnosis: `cat /etc/logrotate.d/nginx` and `systemctl status cron` or `systemctl status logrotate.timer`
- Recovery: Fix the logrotate config and run `logrotate -f /etc/logrotate.d/nginx`
- Prevention: Test logrotate config in staging, monitor log directory size separately.

---

**3. Core dumps accumulating**

If nginx has been crashing (which could itself be a symptom of another issue), core dumps may be filling `/var/crash` or wherever the system is configured to write them.

- Impact: Silent disk fill, may mask the underlying crash cause if not investigated.
- Diagnosis: `ls -lh /var/crash/` and `du -sh /var/crash`
- Recovery: Clear old core dumps after investigating, `rm /var/crash/*`
- Prevention: Configure `ulimit -c 0` in production if core dumps aren't needed, or route them to a size-limited location.

---

**4. Temporary files not being cleaned up**

Some nginx configs buffer large request/response bodies to disk under `/tmp` or a configured temp path. If upstream services are slow or connections are hanging, these temp files accumulate.

- Impact: Gradual disk fill correlated with traffic spikes or upstream slowness.
- Diagnosis: `du -sh /tmp` and check nginx config for `proxy_temp_path`, `client_body_temp_path`
- Recovery: Restart nginx to clear active temp files, clean up `/tmp`
- Prevention: Set appropriate `proxy_max_temp_file_size` and `client_max_body_size` in nginx config.

---

### Monitoring and Alerts to Add

- Disk usage alert at 70% and 85% thresholds (not just 99%)
- Log directory size metric tracked separately
- Alert if nginx error rate spikes (which often precedes or follows disk issues)
- Logrotate success/failure monitoring

---

### Production Prevention Summary

- Logrotate configured and verified working with proper retention policy
- Disk usage monitored with early warning thresholds
- Nginx error log level set appropriately (avoid `debug` in production)
- Regular review of `/var/log`, `/tmp`, `/var/crash` sizes as part of ops hygiene