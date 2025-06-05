using GeoJSON.Net.Feature;
using GeoJSON.Net.Geometry;
using MyCidax.Application.Dtos;
using MyCidax.Domain.Entities;
using MyCidax.Domain.Interfaces;

namespace MyCidax.Application.Services;
public class LocationService : ILocationService
{
    private readonly ILocationRepository _locationRepository;

    public LocationService(ILocationRepository locationRepository)
    {
        _locationRepository = locationRepository;
    }

    public async Task<LocationDto?> CreateLocationAsync(CreateLocationDto createDto)
    {

        var location = Location.Create(createDto.Name, createDto.Category, createDto.Longitude, createDto.Latitude);
        await _locationRepository.AddAsync(location);

        return MapToDto(location);
    }

    public async Task<LocationDto?> GetLocationByIdAsync(Guid id)
    {
        var location = await _locationRepository.GetByIdAsync(id);
        return location == null ? null : MapToDto(location);
    }

    public async Task<IEnumerable<LocationDto>> GetAllLocationsAsync()
    {
        var locations = await _locationRepository.GetAllAsync();
        return locations.Select(MapToDto);
    }

    public async Task<string> GetAllLocationsAsGeoJsonAsync()
    {
        var locations = await _locationRepository.GetAllAsync();
        if (!locations.Any())
        {
            return new FeatureCollection().ToString()!;
        }

        var features = new List<Feature>();
        foreach (var loc in locations)
        {
            var point = new Point(new Position(loc.Coordinates.X, loc.Coordinates.Y));
            var properties = new Dictionary<string, object>
            {
                { "id", loc.Id },
                { "name", loc.Name },
                { "category", loc.Category.ToString() }
            };
            features.Add(new Feature(point, properties, loc.Id.ToString()));
        }

        var featureCollection = new FeatureCollection(features);

        return Newtonsoft.Json.JsonConvert.SerializeObject(featureCollection);
    }


    public async Task<LocationDto?> UpdateLocationAsync(Guid id, UpdateLocationDto updateDto)
    {
        var location = await _locationRepository.GetByIdAsync(id);
        if (location == null)
        {
            return null;
        }

        location.Update(updateDto.Name, updateDto.Category, updateDto.Longitude, updateDto.Latitude);
        await _locationRepository.UpdateAsync(location);

        return MapToDto(location);
    }

    public async Task<bool> DeleteLocationAsync(Guid id)
    {
        if (!await _locationRepository.ExistsAsync(id))
        {
            return false;
        }
        await _locationRepository.DeleteAsync(id);
        return true;
    }

    private LocationDto MapToDto(Location location)
    {
        return new LocationDto
        {
            Id = location.Id,
            Name = location.Name,
            Category = (int)location.Category,
            Longitude = location.Coordinates.X,
            Latitude = location.Coordinates.Y
        };
    }
}

public interface ILocationService
{
    Task<LocationDto?> CreateLocationAsync(CreateLocationDto createDto);
    Task<LocationDto?> GetLocationByIdAsync(Guid id);
    Task<IEnumerable<LocationDto>> GetAllLocationsAsync();
    Task<string> GetAllLocationsAsGeoJsonAsync();
    Task<LocationDto?> UpdateLocationAsync(Guid id, UpdateLocationDto updateDto);
    Task<bool> DeleteLocationAsync(Guid id);
}