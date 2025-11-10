# DNS Configuration Instructions for Client

## What We Need From You

Please provide a **subdomain** from your domain that we can use for VS Code workspaces.

### Examples:
- `ai.yourcompany.com`
- `workspace.yourcompany.com`
- `vscode.yourcompany.com`
- `dev.yourcompany.com`

---

## DNS Configuration Steps

Once you choose a subdomain (e.g., `ai.yourcompany.com`), you need to add a **wildcard DNS record**.

### Step 1: We'll Provide You the IP Address

After we complete the setup, we'll give you an IP address like:
```
34.123.45.67
```

### Step 2: Add DNS Record

In your DNS provider (GoDaddy, Cloudflare, Namecheap, etc.), add this record:

| Field | Value | Example |
|-------|-------|---------|
| **Type** | A | A |
| **Name** | `*.ai` | `*.ai` |
| **Value** | `<IP we provide>` | `34.123.45.67` |
| **TTL** | 300 | 300 |

### Visual Example:

If your subdomain is `ai.yourcompany.com`:
```
Type: A
Name: *.ai
Points to: 34.123.45.67
TTL: 300
```

This creates:
- `vs-code-abc123.ai.yourcompany.com` → Works ✅
- `vs-code-xyz789.ai.yourcompany.com` → Works ✅
- Any `*.ai.yourcompany.com` → Works ✅

---

## What Happens Next

1. **You tell us:** "Use `ai.yourcompany.com`"
2. **We setup:** Ingress controller and get IP address
3. **We give you:** IP address like `34.123.45.67`
4. **You add:** DNS record `*.ai` → `34.123.45.67`
5. **Wait:** 5-10 minutes for DNS propagation
6. **Done:** Users access `https://vs-code-{uuid}.ai.yourcompany.com`

---

## Example Configurations

### Example 1: Using "ai" subdomain
```
Your domain: company.com
Subdomain: ai.company.com
DNS Record: *.ai → 34.123.45.67
User access: https://vs-code-abc123.ai.company.com
```

### Example 2: Using "workspace" subdomain
```
Your domain: myapp.io
Subdomain: workspace.myapp.io
DNS Record: *.workspace → 34.123.45.67
User access: https://vs-code-abc123.workspace.myapp.io
```

### Example 3: Using "dev" subdomain
```
Your domain: platform.com
Subdomain: dev.platform.com
DNS Record: *.dev → 34.123.45.67
User access: https://vs-code-abc123.dev.platform.com
```

---

## DNS Provider Specific Instructions

### Cloudflare
1. Go to DNS settings
2. Click "Add record"
3. Type: `A`
4. Name: `*.ai` (replace with your subdomain)
5. IPv4 address: `<IP we provide>`
6. Proxy status: DNS only (gray cloud)
7. TTL: Auto
8. Save

### GoDaddy
1. Go to DNS Management
2. Click "Add"
3. Type: `A`
4. Host: `*.ai`
5. Points to: `<IP we provide>`
6. TTL: 600 seconds
7. Save

### Namecheap
1. Go to Advanced DNS
2. Click "Add New Record"
3. Type: `A Record`
4. Host: `*.ai`
5. Value: `<IP we provide>`
6. TTL: Automatic
7. Save

### AWS Route 53
1. Go to Hosted Zones
2. Select your domain
3. Create Record
4. Record name: `*.ai`
5. Record type: `A`
6. Value: `<IP we provide>`
7. TTL: 300
8. Create

---

## Verification

After adding the DNS record, test it:

```bash
# Replace with your actual subdomain
nslookup vs-code-test.ai.yourcompany.com

# Should return the IP address we provided
```

Or use online tools:
- https://dnschecker.org
- https://mxtoolbox.com/DNSLookup.aspx

---

## Timeline

- **DNS propagation:** 5-60 minutes (usually 5-10 minutes)
- **SSL certificate:** 2-5 minutes (automatic via Let's Encrypt)
- **Total setup time:** ~15 minutes after DNS is configured

---

## Questions?

**Q: Can I use the root domain instead of subdomain?**
A: Yes, but we recommend a subdomain for better organization.

**Q: Will this affect my existing website?**
A: No, this only affects the subdomain you choose (e.g., `ai.yourcompany.com`), not your main site.

**Q: Can I change the subdomain later?**
A: Yes, just update the DNS record and let us know.

**Q: Do I need SSL certificates?**
A: No, we handle SSL automatically with Let's Encrypt (free).

---

## Summary

✅ **You provide:** Subdomain name (e.g., `ai.yourcompany.com`)
✅ **We provide:** IP address (e.g., `34.123.45.67`)
✅ **You configure:** DNS record `*.ai` → IP address
✅ **Result:** Users access `https://vs-code-{uuid}.ai.yourcompany.com`
