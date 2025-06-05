using MyCidax.Domain.Entities;

namespace MyCidax.Domain.Interfaces;

public interface ILocationRepository
{
    Task AddAsync(Location location);
    Task<Location?> GetByIdAsync(Guid id);
    Task<IEnumerable<Location>> GetAllAsync();
    Task UpdateAsync(Location location);
    Task DeleteAsync(Guid id);
    Task<bool> ExistsAsync(Guid id);
}