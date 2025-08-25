import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import metadata from "./metadata.js";
import { getCountryInfo } from "./utils/travelAdvisory.js";

let SHORT_DELAY = true;
const LONG_DELAY_MS = 100;
const SHORT_DELAY_MS = 50;

const create = () => {
    const mcpServer = new McpServer({
        name: "demo-mcp-server",
        version: metadata.version
    }, {
        capabilities: {
            tools: {}
        }
    });

    mcpServer.tool("ping", async () => {
        const startTime = Date.now();
        SHORT_DELAY=!SHORT_DELAY;

        if (SHORT_DELAY){
            await new Promise((resolve) => setTimeout(resolve, SHORT_DELAY_MS));
        } else {
            await new Promise((resolve) => setTimeout(resolve, LONG_DELAY_MS));
        }
        const duration = Date.now() - startTime;

        return {
            content: [
                {
                    type: "text",
                    text: `pong! logStream=${metadata.logStreamName} v=${metadata.version} d=${duration}`
                }
            ]
        }
    });

    mcpServer.tool("get_time", async () => {
        const now = new Date();
        return {
            content: [
                {
                    type: "text",
                    text: `Current server time is ${now.toISOString()}`
                }
            ]
        }
    });

    mcpServer.tool("get_country_info", async ({ country_name_in_french }) => {
        const info = await getCountryInfo(country_name_in_french);
        return {
            content: [
                {
                    type: "text",
                    text: info || "No information found for the given country."
                }
            ]
        }
    });

    mcpServer.registerResource(
        "travel-advisory",
        new ResourceTemplate("travel://countries/{country_name_in_french}", { list: undefined }),
        {
            title: "Travel Advisory",
            description: "Travel advisory information for a given country"
        },
        async (uri, { country_name_in_french }) => {
            const info = await getCountryInfo(country_name_in_french);
            return {
                contents: [{
                    uri: uri.href,
                    text: info || "No information found for the given country."
                }]
            };
        }
    );

    return mcpServer
};

export default { create };