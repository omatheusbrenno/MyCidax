using MyCidax.Exceptions;

namespace MyCidax.Domain.Validators
{
    public static class DomainValidator
    {
        public static void ValidateName(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException(ExceptionMessages.EMPTY_NAME, nameof(name));

            if (name.Length < 3 || name.Length > 50)
                throw new ArgumentException(ExceptionMessages.INVALID_NAME_LENGTH, nameof(name));
        }

        public static void ValidateLatitude(double? latitude)
        {
            if (!latitude.HasValue)
                throw new ArgumentException(ExceptionMessages.EMPTY_LATITUDE, nameof(latitude));

            if (latitude < -90 || latitude > 90)
                throw new ArgumentOutOfRangeException(nameof(latitude), ExceptionMessages.INVALID_LATITUDE);
        }

        public static void ValidateLongitude(double? longitude)
        {
            if (!longitude.HasValue)
                throw new ArgumentException(ExceptionMessages.INVALID_LONGITUDE, nameof(longitude));

            if (longitude < -180 || longitude > 180)
                throw new ArgumentOutOfRangeException(nameof(longitude), ExceptionMessages.INVALID_LONGITUDE);
        }

        public static void ValidateCategory(int category)
        {
            if (category < 0 || category > 7)
                throw new ArgumentOutOfRangeException(nameof(category), ExceptionMessages.INVALID_CATEGORY);
        }
    }
}