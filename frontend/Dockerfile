
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

# Stage 2: Serve the React application using Nginx
FROM nginx:stable-alpine

# Copy custom Nginx configuration to support React Router
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the generated React build into Nginx
COPY --from=build /app/dist /usr/share/nginx/html

# Document the HTTP port used by Nginx
EXPOSE 80

# Keep Nginx running in the foreground
CMD ["nginx", "-g", "daemon off;"]

