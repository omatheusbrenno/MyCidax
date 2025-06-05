using MyCidax.Domain.Enums;
using MyCidax.Domain.Validators;
using NetTopologySuite.Geometries;

namespace MyCidax.Domain.Entities;

public class Location
{
    public Guid Id { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public LocationCategory Category { get; private set; }
    public Point Coordinates { get; private set; } = default!;

    private Location() { }

    public static Location Create(string name, LocationCategory category, double longitude, double latitude)
    {
        DomainValidator.ValidateName(name);
        DomainValidator.ValidateCategory((int)category);
        DomainValidator.ValidateLongitude(longitude);
        DomainValidator.ValidateLatitude(latitude);

        var coordinates = new Point(longitude, latitude) { SRID = 4326 };

        return new Location
        {
            Id = Guid.NewGuid(),
            Name = name,
            Category = category,
            Coordinates = coordinates
        };
    }

    public void Update(string name, LocationCategory category, double longitude, double latitude)
    {
        DomainValidator.ValidateName(name);
        DomainValidator.ValidateCategory((int)category);
        DomainValidator.ValidateLongitude(longitude);
        DomainValidator.ValidateLatitude(latitude);

        Name = name;
        Category = category;
        Coordinates = new Point(longitude, latitude) { SRID = 4326 };
    }
}
