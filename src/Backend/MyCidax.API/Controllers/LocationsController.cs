using Microsoft.AspNetCore.Mvc;
using MyCidax.Application.Dtos;
using MyCidax.Application.Services;

namespace MyCidax.Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class LocationsController : ControllerBase
{
    private readonly ILocationService _locationService;

    public LocationsController(ILocationService locationService)
    {
        _locationService = locationService;
    }

    [HttpPost]
    [ProducesResponseType(typeof(LocationDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateLocation([FromBody] CreateLocationDto createDto)
    {

        try
        {
            var locationDto = await _locationService.CreateLocationAsync(createDto);
            
            return CreatedAtAction(nameof(GetLocationById), new { id = locationDto?.Id }, locationDto);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<LocationDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<LocationDto>>> GetAllLocations()
    {
        var locations = await _locationService.GetAllLocationsAsync();
        return Ok(locations);
    }

    [HttpGet("geojson")]
    [ProducesResponseType(typeof(string), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAllLocationsAsGeoJson()
    {
        var geoJson = await _locationService.GetAllLocationsAsGeoJsonAsync();
        return Content(geoJson, "application/json");
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(LocationDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<LocationDto>> GetLocationById(Guid id)
    {
        var locationDto = await _locationService.GetLocationByIdAsync(id);
        
        return Ok(locationDto);
    }

    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(LocationDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateLocation(Guid id, [FromBody] UpdateLocationDto updateDto)
    {

        try
        {
            var updatedLocationDto = await _locationService.UpdateLocationAsync(id, updateDto);
            
            return Ok(updatedLocationDto);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteLocation(Guid id)
    {
        var success = await _locationService.DeleteLocationAsync(id);
       
        return NoContent();
    }
}