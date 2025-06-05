using Microsoft.EntityFrameworkCore;
using MyCidax.Domain.Entities;


namespace MyCidax.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Location> Locations { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.HasPostgresExtension("postgis");

        modelBuilder.Entity<Location>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(50);

            entity.Property(e => e.Category)
                  .IsRequired()
                  .HasConversion<int>();

            entity.Property(e => e.Coordinates)
                  .HasColumnType("geography(Point, 4326)") 
                  .IsRequired();

            entity.HasIndex(e => e.Coordinates).HasMethod("GIST");
        });
    }
}
