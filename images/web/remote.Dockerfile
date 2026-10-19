# syntax=docker/dockerfile:1
# Deployment-owned image for the ten federated web remotes (eia-<vertical>-web).
#
# Build context: the owning web repository, after `npm run build` has produced dist/:
#   docker build -f repos/eia-ops/images/web/remote.Dockerfile -t eia/party-web:local repos/eia-party-web
#
# The bundle is served at "/" (nginx, port 80). The Ingress strips the
# /remotes/<vertical> prefix with an nginx rewrite, and Webpack's automatic public
# path resolves remoteEntry.js chunks relative to that URL, so both the entry and
# every lazy chunk land under /remotes/<vertical>/ without a rebuild.
FROM nginx:1.27-alpine

COPY dist/ /usr/share/nginx/html

# The nginx config lives in the image because the build context is the web
# repository, which cannot reference files under eia-ops. Keep this block in sync
# with images/README.md ("Web remote images").
RUN printf '%s\n' \
    'server {' \
    '    listen 80;' \
    '    server_name _;' \
    '' \
    '    root /usr/share/nginx/html;' \
    '    index index.html;' \
    '' \
    '    location = /healthz {' \
    '        access_log off;' \
    '        add_header Content-Type text/plain;' \
    '        return 200 "ok\n";' \
    '    }' \
    '' \
    '    location = /remoteEntry.js {' \
    '        add_header Cache-Control "no-store";' \
    '        try_files $uri =404;' \
    '    }' \
    '' \
    '    location ~* \.(?:js|css)$ {' \
    '        add_header Cache-Control "public, max-age=31536000, immutable";' \
    '        try_files $uri =404;' \
    '    }' \
    '' \
    '    location / {' \
    '        try_files $uri $uri/ /index.html;' \
    '    }' \
    '}' \
    > /etc/nginx/conf.d/default.conf

EXPOSE 80
