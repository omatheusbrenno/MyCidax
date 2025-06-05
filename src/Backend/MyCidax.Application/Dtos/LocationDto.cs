using MyCidax.Domain.Enums;

namespace MyCidax.Application.Dtos;

public class LocationDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int Category { get; set; }
    public double Longitude { get; set; }
    public double Latitude { get; set; }
}

public class CreateLocationDto
{
    public string Name { get; set; } = string.Empty;
    public LocationCategory Category { get; set; }
    public double Longitude { get; set; }
    public double Latitude { get; set; }
}

public class UpdateLocationDto
{
    public string Name { get; set; } = string.Empty;
    public LocationCategory Category { get; set; }
    public double Longitude { get; set; }
    public double Latitude { get; set; }
}