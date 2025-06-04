using FluentValidation;
using MyCidax.Application.Dtos;
using MyCidax.Domain.Enums;
using MyCidax.Exceptions;

namespace MyCidax.Application.Validators;

public class CreateLocationDtoValidator : AbstractValidator<CreateLocationDto>
{
    public CreateLocationDtoValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage(ExceptionMessages.EMPTY_NAME)
            .MinimumLength(3).WithMessage(ExceptionMessages.INVALID_NAME_LENGTH)
            .MaximumLength(50).WithMessage(ExceptionMessages.INVALID_NAME_LENGTH);

        RuleFor(x => x.Category)
            .IsInEnum().WithMessage(ExceptionMessages.INVALID_CATEGORY)
            .Must(category => Enum.IsDefined(typeof(LocationCategory), category))
            .WithMessage(ExceptionMessages.INVALID_CATEGORY);

        RuleFor(x => x.Latitude)
            .NotEmpty().WithMessage(ExceptionMessages.EMPTY_LATITUDE)
            .InclusiveBetween(-90, 90).WithMessage(ExceptionMessages.INVALID_LATITUDE);

        RuleFor(x => x.Longitude)
            .NotEmpty().WithMessage(ExceptionMessages.EMPTY_LONGITUDE)
            .InclusiveBetween(-180, 180).WithMessage(ExceptionMessages.INVALID_LONGITUDE);
    }
}

public class UpdateLocationDtoValidator : AbstractValidator<UpdateLocationDto>
{
    public UpdateLocationDtoValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage(ExceptionMessages.EMPTY_NAME)
            .MinimumLength(3).WithMessage(ExceptionMessages.INVALID_NAME_LENGTH)
            .MaximumLength(50).WithMessage(ExceptionMessages.INVALID_NAME_LENGTH);

        RuleFor(x => x.Category)
            .IsInEnum().WithMessage(ExceptionMessages.INVALID_CATEGORY)
            .Must(category => Enum.IsDefined(typeof(LocationCategory), category))
            .WithMessage(ExceptionMessages.INVALID_CATEGORY);

        RuleFor(x => x.Latitude)
            .NotEmpty().WithMessage(ExceptionMessages.EMPTY_LATITUDE)
            .InclusiveBetween(-90, 90).WithMessage(ExceptionMessages.INVALID_LATITUDE);

        RuleFor(x => x.Longitude)
            .NotEmpty().WithMessage(ExceptionMessages.EMPTY_LONGITUDE)
            .InclusiveBetween(-180, 180).WithMessage(ExceptionMessages.INVALID_LONGITUDE);
    }
}