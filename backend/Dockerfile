FROM node:22-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev && \
    rm -rf /usr/local/lib/node_modules/npm \
           /usr/local/lib/node_modules/corepack \
           /opt/yarn-v1.22.22 && \
    rm -f /usr/local/bin/npm \
          /usr/local/bin/npx \
          /usr/local/bin/corepack \
          /usr/local/bin/yarn \
          /usr/local/bin/yarnpkg

COPY app.js server.js ./
COPY configs/db.js ./configs/
COPY controllers/ ./controllers/
COPY routes/ ./routes/

USER node

EXPOSE 3200

CMD ["node", "server.js"]
