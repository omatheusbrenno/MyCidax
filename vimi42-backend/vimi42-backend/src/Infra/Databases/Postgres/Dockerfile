# Dockerfile
FROM postgres:15

# Copia o script de inicialização para a pasta que o entrypoint do Postgres executa
COPY src/Infra/Databases/Postgres/init.sql /docker-entrypoint-initdb.d/01-init.sql

# Define encodings e variáveis de ambiente se necessário
ENV LANG=C.UTF-8