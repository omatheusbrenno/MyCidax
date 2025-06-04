using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using MyCidax.Domain.Interfaces;
using MyCidax.Infrastructure.Data;
using MyCidax.Infrastructure.Repositories;

namespace MyCidax.Infrastructure;

public static class InfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"),
                x => x.UseNetTopologySuite()));

        services.AddScoped<ILocationRepository, LocationRepository>();

        return services;
    }
}
