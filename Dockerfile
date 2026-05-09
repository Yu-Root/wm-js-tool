FROM docker.m.daocloud.io/node:18

WORKDIR /app

COPY wm-js-tool/package*.json ./
RUN npm install

COPY wm-js-tool/ ./

RUN npm run build

EXPOSE 4173

CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0"]
