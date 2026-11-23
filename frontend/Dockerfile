
# Stage 1: Build the React application using Node.js
FROM node:22-alpine AS build

# Set the working directory inside the build container
WORKDIR /app

# Copy dependency manifests first for Docker layer caching
COPY package*.json ./

# Install all dependencies, including TypeScript and Vite
RUN npm ci

# Copy the React application source code
COPY . .

# Set the backend API URL used by Vite during the build
ARG VITE_API_URL=http://localhost:3200/api
ENV VITE_API_URL=${VITE_API_URL}

# Compile TypeScript and build production-ready static files
RUN npm run build

# Stage 2: Serve React using Nginx
FROM nginx:stable-alpine

# Install available security fixes for libxslt and libxml2
RUN apk upgrade --no-cache libxslt libxml2 && \
    apk add --no-cache libcap-setcap && \
    setcap cap_net_bind_service=+ep /usr/sbin/nginx

COPY nginx.runtime.conf /etc/nginx/nginx.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

USER nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
