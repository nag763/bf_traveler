import requests
from bs4 import BeautifulSoup
from strands import tool


@tool
def get_country_info(country_name_in_french) -> str | None:
    """
    Fetches the 'sécurité' section from the French Ministry of Foreign Affairs travel advice page for a given country.
    Args:
        country_name_in_french (str): The name of the country in French, used to
        construct the URL for the travel advice page.
    Returns:
        str: The text content of the 'sécurité' section if found, otherwise None.
    """
    base_url = "https://www.diplomatie.gouv.fr/fr/conseils-aux-voyageurs/conseils-par-pays-destination/"
    full_url = f"{base_url}{country_name_in_french.lower()}"

    print(f"Fetching data from: {full_url}\n")

    try:
        # 2. Make an HTTP GET request to the URL
        response = requests.get(full_url, headers={"User-Agent": "Mozilla/5.0"})

        # Raise an exception for bad status codes (4xx or 5xx)
        response.raise_for_status()

    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching the URL: {e}")
        return

    # 3. Parse the HTML content of the page
    soup = BeautifulSoup(response.text, "html.parser")

    # 4. Find the 'sécurité' section by its ID
    security_section = soup.find("div", id="securite")

    # 5. Extract and print the content if the section is found
    if security_section:
        # Get the text content of the security section
        security_text = security_section.get_text(separator="\n", strip=True)

        return security_text
    else:
        print("⚠️ 'sécurité' section not found on the page.")
        return None
