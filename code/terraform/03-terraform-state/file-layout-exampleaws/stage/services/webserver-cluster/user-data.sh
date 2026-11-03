#!/bin/bash

################################################################################
# USER DATA SCRIPT FOR WEB SERVER EC2 INSTANCES
################################################################################
# This script runs automatically when each EC2 instance launches.
# It configures the instance as a simple HTTP web server that displays:
# - A "Hello, World" message
# - The database address and port (injected by Terraform templatefile function)
#
# Variables substituted by Terraform:
# - ${db_address}: MySQL database endpoint (from remote state)
# - ${db_port}: MySQL database port (from remote state)
# - ${server_port}: Port on which to run the HTTP server (from variables.tf)
################################################################################

# Create an HTML file with database connection information
# This HTML will be served by the HTTP server
cat > index.html <<EOF
<h1>Hello, World</h1>
<p>DB address: ${db_address}</p>
<p>DB port: ${db_port}</p>
EOF

# Start a lightweight HTTP server using busybox
# - nohup: Run the command immune to hangups (continues after shell closes)
# - busybox httpd: Lightweight HTTP daemon provided by busybox
# - -f: Run in foreground (required for nohup)
# - -p: Listen on the specified port
# - &: Run in background so the script completes
nohup busybox httpd -f -p ${server_port} &
