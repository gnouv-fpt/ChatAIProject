# Multi-stage Dockerfile for ASP.NET Core 8 Web API
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project definition files for cached layer restore
COPY ["ChatAIWeb.slnx", "./"]
COPY ["BusinessObject/BusinessObject.csproj", "BusinessObject/"]
COPY ["DataAccess/DataAccess.csproj", "DataAccess/"]
COPY ["BusinessLogic/BusinessLogic.csproj", "BusinessLogic/"]
COPY ["Presentation/Presentation.csproj", "Presentation/"]
COPY ["Protos/chat_inference.proto", "Protos/"]

RUN dotnet restore "Presentation/Presentation.csproj"

# Copy full source and build
COPY . .
WORKDIR "/src/Presentation"
RUN dotnet build "Presentation.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Presentation.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Presentation.dll"]
