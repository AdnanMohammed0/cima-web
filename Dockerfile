FROM node:20-bookworm-slim

WORKDIR /app

COPY backend/package*.json ./
RUN npm install

# Install Playwright system deps and Chromium
RUN npx playwright install --with-deps chromium 2>&1 || echo "Playwright install had warnings"

COPY backend/ .

EXPOSE 7860
ENV PORT=7860

CMD ["node", "index.js"]