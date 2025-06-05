# Etapa de build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copiando os arquivos de projeto para restaurar as dependências
COPY src/Backend/MyCidax.API/MyCidax.API.csproj ./Backend/MyCidax.API/
COPY src/Backend/MyCidax.Application/MyCidax.Application.csproj ./Backend/MyCidax.Application/
COPY src/Backend/MyCidax.Domain/MyCidax.Domain.csproj ./Backend/MyCidax.Domain/
COPY src/Backend/MyCidax.Infrastructure/MyCidax.Infrastructure.csproj ./Backend/MyCidax.Infrastructure/
COPY src/Shared/MyCidax.Exceptions/MyCidax.Exceptions.csproj ./Shared/MyCidax.Exceptions/

# Restaura os pacotes
WORKDIR /src/Backend/MyCidax.API
RUN dotnet restore

# Copia todo o restante do código
WORKDIR /src
COPY src/Backend/ ./Backend/
COPY src/Shared/ ./Shared/

# Compila o projeto
WORKDIR /src/Backend/MyCidax.API
RUN dotnet build -c Release -o /app/build

# Etapa de publish
FROM build AS publish
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# Imagem final
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .

EXPOSE 8080
ENTRYPOINT ["dotnet", "MyCidax.API.dll"]
