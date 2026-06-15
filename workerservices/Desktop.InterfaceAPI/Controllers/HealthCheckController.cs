using Microsoft.AspNetCore.Mvc;

namespace Desktop.InterfaceAPI.Controllers;

[ApiController]
[Route("health")]
public class HealthCheckController : ControllerBase
{
    [HttpGet]
    public IActionResult HealthCheck()
    {
        return Ok("OK");
    }
}