import fetch from 'node-fetch';
import * as cheerio from 'cheerio';

export async function getCountryInfo(countryNameInFrench) {
    const baseUrl = "https://www.diplomatie.gouv.fr/fr/conseils-aux-voyageurs/conseils-par-pays-destination/";
    const fullUrl = `${baseUrl}${countryNameInFrench.toLowerCase()}`;

    console.log(`Fetching data from: ${fullUrl}`);

    try {
        const response = await fetch(fullUrl, {
            headers: { "User-Agent": "Mozilla/5.0" }
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const html = await response.text();
        const $ = cheerio.load(html);

        const securitySection = $("#securite");

        if (securitySection.length) {
            const securityText = securitySection.text().trim();
            return securityText;
        } else {
            console.warn("'sécurité' section not found on the page.");
            return null;
        }
    } catch (e) {
        console.error(`Error fetching the URL: ${e}`);
        return null;
    }
}
