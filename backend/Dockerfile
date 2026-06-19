FROM node:18-bullseye-slim

WORKDIR /app

COPY package*.json ./
RUN npm install

# Install Chromium with all system dependencies
RUN npx playwright install --with-deps chromium

COPY . .

ENV PORT=7860
EXPOSE 7860

CMD ["node", "index.js"]
