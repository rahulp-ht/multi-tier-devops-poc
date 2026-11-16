
# Use the official Node.js 22 image based on lightweight Alpine Linux
#FROM node:22-alpine

# Set /app as the working directory inside the container
#WORKDIR /app

# Copy package.json and package-lock.json into /app
#COPY package*.json ./

# Install production dependencies using the package-lock.json file
#RUN npm ci --omit=dev

# Copy the remaining backend application files into /app
#COPY . .

# Document that the application listens on port 3200
#EXPOSE 3200

# Start the backend application using the npm start script
#CMD ["npm", "start"]



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

COPY . .

EXPOSE 3200

CMD ["node", "server.js"]
