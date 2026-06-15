var builder = WebApplication.CreateBuilder(args);

// Permite hospedar a API como Servico do Windows (SCM) ou como unidade do
// systemd no Linux. Ambos sao no-op quando executados como console comum,
// e ajustam o content root para o diretorio do executavel quando aplicavel.
builder.Host.UseWindowsService(options =>
{
    options.ServiceName = "Desktop InterfaceAPI";
});
builder.Host.UseSystemd();

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.Run();
