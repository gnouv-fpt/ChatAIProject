FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["BusinessObject/BusinessObject.csproj", "BusinessObject/"]
COPY ["DataAccess/DataAccess.csproj", "DataAccess/"]
COPY ["BusinessLogic/BusinessLogic.csproj", "BusinessLogic/"]
COPY ["WorkerService/WorkerService.csproj", "WorkerService/"]
COPY ["Protos/chat_inference.proto", "Protos/"]
RUN dotnet restore "WorkerService/WorkerService.csproj"
COPY . .
RUN dotnet publish "WorkerService/WorkerService.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "WorkerService.dll"]
