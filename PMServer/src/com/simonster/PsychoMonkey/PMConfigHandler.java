package com.simonster.PsychoMonkey;

import java.io.IOException;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

public class PMConfigHandler implements HttpHandler {
	private final String config;
	
	PMConfigHandler(String configJson) {
		config = "var CONFIG = "+configJson;
	}
	
	public void handle(HttpExchange exchange) throws IOException {
		try {
			byte[] bytes = config.getBytes("UTF-8");
			exchange.getResponseHeaders().add("Content-Type", "application/json");
			exchange.sendResponseHeaders(200, bytes.length);
			exchange.getResponseBody().write(bytes);
		} finally {
			exchange.close();
		}
	}
}
