
# Use the official Node.js 22 image based on lightweight Alpine Linux
FROM node:22-alpine

# Set /app as the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json into /app
COPY package*.json ./

# Install production dependencies using the package-lock.json file
RUN npm ci --omit=dev

# Copy the remaining backend application files into /app
COPY . .

# Document that the application listens on port 3200
EXPOSE 3200

# Start the backend application using the npm start script
CMD ["npm", "start"]

