using System.Diagnostics;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Presentation.Models;

namespace Presentation.Pages;

public sealed class ErrorModel : PageModel
{
    public ErrorViewModel ViewModel { get; private set; } = new();

    public void OnGet()
    {
        ViewModel = new ErrorViewModel
        {
            RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier
        };
    }
}
