FROM node:20-alpine AS build
ARG VITE_ADMIN_API_KEY
ENV VITE_ADMIN_API_KEY=$VITE_ADMIN_API_KEY
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --legacy-peer-deps
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 5174
CMD ["nginx", "-g", "daemon off;"]
