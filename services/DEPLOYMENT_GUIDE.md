# Deployment Guide & Security Checklist

This guide covers deploying the AI Proxy Service and Credits Service to production with proper security configuration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Security Checklist](#security-checklist)
3. [Environment Configuration](#environment-configuration)
4. [Deployment Steps](#deployment-steps)
5. [Monitoring & Observability](#monitoring--observability)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements

- **Python**: 3.13+
- **TigerBeetle**: Latest version (for Credits Service)
- **Docker** (optional): For containerized deployment
- **Reverse Proxy**: Nginx or similar (recommended for production)

### External Services

- **Gemini API**: Valid API key from Google AI Studio
- **TLS Certificates**: For HTTPS (Let's Encrypt recommended)

---

## Security Checklist

Before deploying to production, ensure **ALL** items are completed:

### ✅ Authentication & Authorization

- [ ] Generate strong API keys using: `openssl rand -hex 32`
- [ ] Set `API_KEYS` environment variable with comma-separated keys
- [ ] Store API keys in secure secret management (e.g., AWS Secrets Manager, HashiCorp Vault)
- [ ] Rotate API keys regularly (recommended: every 90 days)
- [ ] Different API keys for AI Proxy and Credits services
- [ ] Never commit API keys to version control
- [ ] Document API key distribution process for clients

### ✅ Network Security

- [ ] Configure CORS allowed origins (`CORS_ALLOWED_ORIGINS`) - **NO wildcards in production**
- [ ] Restrict to specific domains: `https://app.example.com,https://admin.example.com`
- [ ] Deploy behind HTTPS reverse proxy (TLS 1.2 minimum, TLS 1.3 recommended)
- [ ] Configure firewall rules to restrict service access
- [ ] Use private networks for inter-service communication
- [ ] Disable public access to /metrics endpoint (internal monitoring only)
- [ ] Implement IP whitelisting if possible

### ✅ Rate Limiting

- [ ] Configure `RATE_LIMIT_ENABLED=true`
- [ ] Set appropriate `RATE_LIMIT_PER_MINUTE` (default: 60)
- [ ] Consider using Redis for distributed rate limiting (multi-instance deployments)
- [ ] Monitor rate limit violations via logs
- [ ] Adjust limits based on usage patterns

### ✅ Error Handling & Logging

- [ ] Set `LOG_LEVEL=WARNING` or `INFO` in production (avoid `DEBUG`)
- [ ] Ensure error responses don't leak internal details
- [ ] Configure log aggregation (e.g., CloudWatch, Datadog, ELK stack)
- [ ] Set up alerts for error spikes
- [ ] Review logs regularly for security anomalies

### ✅ Dependency Security

- [ ] Run `pip audit` to check for vulnerable dependencies
- [ ] Keep dependencies up to date
- [ ] Pin dependency versions in requirements.txt
- [ ] Review security advisories for FastAPI, uvicorn, and other libraries
- [ ] Use Docker base images from trusted sources
- [ ] Scan Docker images for vulnerabilities

### ✅ Database & Storage

- [ ] TigerBeetle data files stored on persistent volumes
- [ ] Configure backups for TigerBeetle data
- [ ] Test restore procedures
- [ ] Encrypt sensitive data at rest
- [ ] Restrict database access to Credits Service only

### ✅ Monitoring & Observability

- [ ] Configure health check monitoring
- [ ] Set up uptime monitoring (e.g., Pingdom, UptimeRobot)
- [ ] Monitor /metrics endpoint for anomalies
- [ ] Alert on high error rates (>5%)
- [ ] Alert on billing failures
- [ ] Track API usage and costs
- [ ] Monitor TigerBeetle performance

### ✅ Disaster Recovery

- [ ] Document rollback procedures
- [ ] Maintain staging environment for testing
- [ ] Test failure scenarios (API outage, database failure, etc.)
- [ ] Document incident response procedures
- [ ] Regular backup verification

---

## Environment Configuration

### AI Proxy Service (.env)

```bash
# Google Gemini API Key (required)
GEMINI_API_KEY=your_actual_gemini_api_key_here

# API Authentication (required for production)
# Generate with: openssl rand -hex 32
API_KEYS=key1_long_random_string,key2_long_random_string

# Service Configuration
PORT=8002
LOG_LEVEL=INFO

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60

# CORS Configuration (restrict to your domains)
CORS_ALLOWED_ORIGINS=https://app.yourcompany.com,https://admin.yourcompany.com

# Credits Service Integration (Phase 2)
CREDITS_SERVICE_URL=http://credits-service:8001
CREDITS_SERVICE_API_KEY=your_credits_service_api_key_here
```

### Credits Service (.env)

```bash
# API Authentication (required for production)
# Generate with: openssl rand -hex 32
API_KEYS=credits_key1_long_random_string,credits_key2_long_random_string

# Service Configuration
PORT=8001
LOG_LEVEL=INFO

# CORS Configuration (restrict to your domains + AI proxy)
CORS_ALLOWED_ORIGINS=https://app.yourcompany.com,http://ai-proxy-service:8002

# TigerBeetle Configuration
TIGERBEETLE_CLUSTER_ID=0
TIGERBEETLE_HOST=tigerbeetle
TIGERBEETLE_PORT=3000
```

---

## Deployment Steps

### Option 1: Docker Compose (Recommended for Development/Staging)

```bash
# 1. Start TigerBeetle
cd services/credits-service
docker-compose up -d tigerbeetle

# 2. Start Credits Service
docker-compose up -d credits-service

# 3. Start AI Proxy Service
cd ../ai-proxy-service
docker-compose up -d
```

### Option 2: Production Deployment (Kubernetes/ECS/Cloud Run)

1. **Build Docker Images**:
   ```bash
   # AI Proxy Service
   cd services/ai-proxy-service
   docker build -t your-registry/ai-proxy:v1.0.0 .

   # Credits Service
   cd ../credits-service
   docker build -t your-registry/credits-service:v1.0.0 .
   ```

2. **Deploy TigerBeetle** (as a StatefulSet in Kubernetes or persistent container)

3. **Deploy Credits Service** with environment variables from secrets

4. **Deploy AI Proxy Service** with environment variables from secrets

5. **Configure Reverse Proxy** (Nginx example):
   ```nginx
   server {
       listen 443 ssl http2;
       server_name api.yourcompany.com;

       ssl_certificate /etc/ssl/certs/cert.pem;
       ssl_certificate_key /etc/ssl/private/key.pem;

       # AI Proxy
       location /ai/ {
           proxy_pass http://ai-proxy-service:8002/;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }

       # Credits Service (restrict to internal only)
       location /credits/ {
           # Only accessible from internal network
           allow 10.0.0.0/8;
           deny all;
           proxy_pass http://credits-service:8001/api/v1/;
       }
   }
   ```

---

## Monitoring & Observability

### Health Checks

```bash
# AI Proxy Service
curl https://api.yourcompany.com/ai/health

# Credits Service (internal)
curl http://credits-service:8001/api/v1/health
```

### Metrics

```bash
# AI Proxy Metrics (restrict to internal monitoring)
curl http://ai-proxy-service:8002/metrics

# Example output:
{
  "service": "AI Proxy Service",
  "timestamp": "2025-01-15T10:30:00Z",
  "uptime_seconds": 3600.5,
  "requests": {
    "total": 1250,
    "successful": 1200,
    "failed": 50,
    "success_rate_percent": 96.0,
    "by_model": {
      "gemini-pro": 800,
      "gemini-flash": 400
    }
  },
  "tokens": {
    "total": 2500000,
    "prompt": 1000000,
    "completion": 1500000
  },
  "billing": {
    "total_cost_usd": 125.50
  },
  "performance": {
    "avg_response_time_seconds": 2.5,
    "min_response_time_seconds": 0.8,
    "max_response_time_seconds": 8.2
  }
}
```

### Logs

Monitor these log patterns:

- **Authentication failures**: `Authentication failed: Invalid API key`
- **Rate limit exceeded**: `Rate limit exceeded`
- **Billing failures**: `Billing failed for`
- **AI provider errors**: `AI provider error`
- **Insufficient balance**: `Insufficient balance`

### Alerts (Configure in your monitoring system)

1. **Error Rate > 5%**: Investigate immediately
2. **Response Time > 10s avg**: Performance degradation
3. **Billing Service Down**: Critical - blocks AI requests
4. **TigerBeetle Unavailable**: Critical - database down
5. **Rate Limit Violations Spike**: Possible abuse

---

## Troubleshooting

### Common Issues

#### 1. "No API keys configured" on startup

**Cause**: `API_KEYS` environment variable not set

**Fix**:
```bash
export API_KEYS=$(openssl rand -hex 32)
# Or set in your .env file
```

#### 2. "Authentication failed: Missing Authorization header"

**Cause**: Client not sending Authorization header

**Fix**: Ensure client sends:
```
Authorization: Bearer your_api_key_here
```

#### 3. "Insufficient balance" errors

**Cause**: User account balance too low

**Fix**: Top up user account via Credits Service:
```bash
curl -X POST http://credits-service:8001/api/v1/topup \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user@example.com", "amount": 100.0}'
```

#### 4. "Billing service unavailable"

**Cause**: Credits Service is down or unreachable

**Fix**:
- Check Credits Service health: `curl http://credits-service:8001/api/v1/health`
- Check network connectivity between services
- Review Credits Service logs

#### 5. Rate limit exceeded (429 errors)

**Cause**: Too many requests from single IP

**Fix**:
- Increase `RATE_LIMIT_PER_MINUTE` if legitimate traffic
- Implement Redis-based rate limiting for distributed deployments
- Investigate if it's abuse (check logs for patterns)

#### 6. CORS errors in browser

**Cause**: Frontend origin not in `CORS_ALLOWED_ORIGINS`

**Fix**: Add your frontend domain:
```bash
CORS_ALLOWED_ORIGINS=https://app.yourcompany.com
```

---

## Security Incident Response

### If API Keys are Compromised:

1. **Immediately rotate keys**:
   ```bash
   # Generate new keys
   NEW_KEY=$(openssl rand -hex 32)

   # Update environment variable
   export API_KEYS="$NEW_KEY"

   # Restart services
   ```

2. **Review logs** for unauthorized access:
   ```bash
   grep "Authentication successful" logs/ | grep <suspicious_timeframe>
   ```

3. **Notify affected clients** of key rotation

4. **Audit billing records** for fraudulent usage

### If Service is Compromised:

1. **Isolate affected service** (take offline if necessary)
2. **Review all logs** for suspicious activity
3. **Check for data exfiltration**
4. **Restore from clean backup** if needed
5. **Update all secrets** (API keys, credentials)
6. **Perform security audit** before bringing back online

---

## Maintenance

### Regular Tasks

- **Daily**: Monitor error rates and billing metrics
- **Weekly**: Review security logs for anomalies
- **Monthly**: Dependency security audit (`pip audit`)
- **Quarterly**: API key rotation, penetration testing
- **Annually**: Full security audit, disaster recovery drill

### Backup Procedures

```bash
# TigerBeetle backup (adjust path to your data file)
tar -czf tigerbeetle-backup-$(date +%Y%m%d).tar.gz /var/lib/tigerbeetle/

# Upload to secure storage (S3, GCS, etc.)
aws s3 cp tigerbeetle-backup-*.tar.gz s3://your-backup-bucket/
```

---

## Support & Resources

- **AI Proxy Service README**: `services/ai-proxy-service/README.md`
- **Credits Service README**: `services/credits-service/README.md`
- **TigerBeetle Docs**: https://docs.tigerbeetle.com
- **FastAPI Security**: https://fastapi.tiangolo.com/tutorial/security/

---

## Changelog

### v1.0.0 (2025-01-15)
- Initial deployment guide
- Security checklist for production
- Monitoring and observability guidelines
- Troubleshooting guide

---

**⚠️ IMPORTANT**: This guide assumes you have completed all items in the Security Checklist. **DO NOT** deploy to production until all security measures are in place.
