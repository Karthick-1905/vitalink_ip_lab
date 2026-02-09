# Stage 1: Build
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies
RUN npm install

# Copy source code
COPY . .

# Run build (tsc && tsc-alias)
RUN npm run build

# Stage 2: Production
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm install --omit=dev

# Copy built files from the build stage
COPY --from=build /app/build ./build

# Create uploads directory (if needed)
RUN mkdir -p uploads/profiles

# Expose the port (Render will use PORT env var usually)
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
