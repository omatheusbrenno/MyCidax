# MyCidax API .NET

API REST em .NET 8 para gerenciamento de locais geográficos, utilizando PostgreSQL com PostGIS para armazenamento de dados geoespaciais (SRID 4326) e Docker para containerização.

<p align="center">
  <img src="https://github.com/user-attachments/assets/23b731c3-0e28-4fa6-a99f-b5d3076d8e04" alt="MyCidax.API - Swagger" />
</p>

## Funcionalidades

- Cadastro (Create) de locais com nome, categoria e coordenadas (latitude/longitude).
- Listagem (Read) de todos os locais cadastrados.
- Listagem (Read) de locais em formato GeoJSON.
- Busca por ID (Read) de um local específico.
- Atualização (Update) dos dados de um local.
- Exclusão (Delete) de um local específico.
- Validações de dados de entrada.
 > - `Nome:` Não pode ser vazio, deve ter entre 3 e 50 caracteres.
 > - `Categoria:` Deve ser uma das categorias `numéricas` pré-definidas (`0` = Outro, `1` = Farmacia, `2` = Restaurante, `3` = Hospital, `4` = Mercado, `5` = Parque, `6` = Escola, `7` = Residencia).
 > - `Latitude:` Não pode ser vazio, deve estar entre -90 e 90.
 > - `Longitude:` Não pode ser vazio, deve estar entre -180 e 180.
- Categorias pré-definidas para locais.

## Tecnologias Utilizadas

- **.NET 8 (C#)**: Framework para desenvolvimento da API.
- **ASP.NET Core**: Para construção de APIs REST.
- **Entity Framework Core**: ORM para interação com o banco de dados.
- **PostgreSQL com PostGIS**: Banco de dados relacional com extensões para dados geoespaciais.
- **NetTopologySuite**: Biblioteca para manipulação de dados geoespaciais no .NET.
- **GeoJSON.Net**: Biblioteca para trabalhar com o formato GeoJSON.
- **FluentValidation**: Para validações de DTOs.
- **Docker & Docker Compose**: Para containerização da aplicação e do banco de dados.
- **Swagger (OpenAPI)**: Para documentação e teste da API.

## Estrutura do Projeto (DDD-like)

- sln
- src
   - docker-compose.yml
   - Backend
    > - `MyCidax.API`: Controllers ASP.NET Core, Configuração da API, Dockerfile.
    > - `MyCidax.Domain`: Entidades, Enums, Interfaces de Repositório.
    > - `MyCidax.Application`: DTOs, Serviços de Aplicação, Validações.
    > - `MyCidax.Infrastructure`: Implementações de Repositório, DbContext (EF Core), Migrações.
   - Shared
    > - `MyCidax.Exceptions`: Controllers ASP.NET Core, Configuração da API, Dockerfile.
- tests

## Pré-requisitos

- [.NET SDK 8.0+](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)

## Como Rodar e Testar a Aplicação

- Acesse o terminal cmd do windows
- Execute os comandos linha por linha
- Acesse a API no seu navegador: http://localhost:8080/swagger
  
### 1. Clonar o Repositório

```bash
git clone https://github.com/omatheusbrenno/MyCidax.git

cd MyCidax/src/Backend/MyCidax.API

dotnet ef migrations add InitialCreate --project ../MyCidax.Infrastructure --startup-project . --output-dir Data/Migrations

dotnet ef database update --project ../MyCidax.Infrastructure --startup-project .

docker-compose up --build
