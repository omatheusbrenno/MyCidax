using FluentValidation.AspNetCore;
using FluentValidation;
using MyCidax.Api.Middleware;
using MyCidax.Application.Validators;
using MyCidax.Infrastructure.Data;
using MyCidax.Infrastructure;
using Microsoft.EntityFrameworkCore;
using MyCidax.Application.Services;

var builder = WebApplication.CreateBuilder(args);

// Serviços padrão
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// FluentValidation
builder.Services.AddFluentValidationAutoValidation();
builder.Services.AddValidatorsFromAssemblyContaining<CreateLocationDtoValidator>();

// DbContext com PostgreSQL
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        b => b.MigrationsAssembly("MyCidax.Infrastructure")
    ));

// Infraestrutura
builder.Services.AddInfrastructure(builder.Configuration);

// Aplicação
builder.Services.AddScoped<ILocationService, LocationService>();

var app = builder.Build();

// Migrations automáticas
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    dbContext.Database.Migrate();
}

app.UseMiddleware<GlobalExceptionHandlerMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();