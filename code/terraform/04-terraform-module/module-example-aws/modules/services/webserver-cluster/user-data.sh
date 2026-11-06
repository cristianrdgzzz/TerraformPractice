#!/bin/bash
#
# Simple user-data script for example EC2 instances.
#
# This file is used by `templatefile()` in the Terraform module. The module
# substitutes the variables `server_port`, `db_address`, and `db_port` into
# the template before passing it to the instance. The script writes a simple
# `index.html` and launches a tiny HTTP server (busybox httpd) that serves the
# file on the configured port.
#
# Note: This is intentionally minimal for educational purposes. Use cloud-init
# or more robust configuration management for production systems.

cat > index.html <<EOF
<h1>Hello, World</h1>
<p>DB address: ${db_address}</p>
<p>DB port: ${db_port}</p>
EOF

# Launch a simple web server in the background. `nohup` ensures the process
# continues running after the user-data script completes. `busybox httpd`
# provides a lightweight web server that can serve the generated `index.html`.
nohup busybox httpd -f -p ${server_port} &
