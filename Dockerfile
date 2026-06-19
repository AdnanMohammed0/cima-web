FROM mcr.microsoft.com/playwright:v1.44.0-jammy

WORKDIR /app

COPY backend/package*.json ./
RUN npm install

COPY backend/ .

EXPOSE 7860
ENV PORT=7860

CMD ["node", "index.js"]