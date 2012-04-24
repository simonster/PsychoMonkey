package com.simonster.PsychoMonkey;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.net.URI;
import java.net.URLDecoder;

import javax.activation.MimetypesFileTypeMap;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

public class PMStaticHandler implements HttpHandler {
	File assetsDirectory;
	MimetypesFileTypeMap mimeTypeMap;
	
	public PMStaticHandler() {
		File classFile;
		try {
			classFile = new File(URLDecoder.decode(
					PMStaticHandler.class.getProtectionDomain().getCodeSource().getLocation().getPath(),
					"UTF-8"));
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
			return;
		}
		while(!classFile.getName().equals("PMServer")) {
			classFile = classFile.getParentFile();
		}
		assetsDirectory = new File(classFile, "assets");
		mimeTypeMap = new MimetypesFileTypeMap();
	}
	
	public void handle(HttpExchange exchange) throws IOException {
		try {
			URI uri = exchange.getRequestURI();
			String asset = uri.getPath().substring(1);
			if(asset.equals("") || asset.charAt(asset.length()-1) == '/') {
				asset += "index.html";
			}
			File assetFile = new File(assetsDirectory, asset);
			
			// Verify that this file is actually a child of the assets directory
			boolean isSafe = false;
			try {
				isSafe = assetFile.getCanonicalPath().startsWith(assetsDirectory.getCanonicalPath());
			} catch (IOException e) {}
			if(!isSafe) {
				exchange.sendResponseHeaders(403, -1);
				return;
			}
			
			// Verify that file exists
			if(!assetFile.exists()) {
				exchange.sendResponseHeaders(404, -1);
				return;
			}
			
			// Send file
			exchange.getResponseHeaders().add("Content-Type", mimeTypeMap.getContentType(assetFile));
			exchange.sendResponseHeaders(200, assetFile.length());
			FileInputStream in = new FileInputStream(assetFile);
			OutputStream out = exchange.getResponseBody();
			byte[] buffer = new byte[4096];
			int bytesRead = 0;
			while(bytesRead != -1) {
				bytesRead = in.read(buffer);
				out.write(buffer, 0, bytesRead);
			}
		} finally {
			exchange.close();
		}
	}
}
