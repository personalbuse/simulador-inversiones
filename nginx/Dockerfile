FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN mkdir -p /etc/nginx/includes /var/log/nginx && \
    chown -R nginx:nginx /var/log/nginx

COPY includes/ /etc/nginx/includes/

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]