using Microsoft.EntityFrameworkCore;
using MyCidax.Domain.Entities;
using MyCidax.Domain.Interfaces;
using MyCidax.Infrastructure.Data;

namespace MyCidax.Infrastructure.Repositories;

public class LocationRepository : ILocationRepository
{
    private readonly AppDbContext _context;

    public LocationRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(Location location)
    {
        await _context.Locations.AddAsync(location);
        await _context.SaveChangesAsync();
    }

    public async Task<Location?> GetByIdAsync(Guid id)
    {
        return await _context.Locations.FindAsync(id);
    }

    public async Task<IEnumerable<Location>> GetAllAsync()
    {
        return await _context.Locations.ToListAsync();
    }

    public async Task UpdateAsync(Location location)
    {
        _context.Locations.Update(location);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid id)
    {
        var location = await _context.Locations.FindAsync(id);
        if (location != null)
        {
            _context.Locations.Remove(location);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<bool> ExistsAsync(Guid id)
    {
        return await _context.Locations.AnyAsync(e => e.Id == id);
    }
}