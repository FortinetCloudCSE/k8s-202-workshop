package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"

    "github.com/google/generative-ai-go/genai"
    "google.golang.org/api/option"
)

// PageData holds the data to be displayed in the template
type PageData struct {
    Response string `json:"response"`
    Error    string `json:"error"`
}

func main() {
    http.HandleFunc("/generate", generateHandler)
    http.HandleFunc("/info", infoHandler)
    http.HandleFunc("/help", helpHandler)
    http.Handle("/", http.FileServer(http.Dir("./static")))

    port := os.Getenv("PORT")
    if port == "" {
        port = "80"
    }
    
    fmt.Printf("Server started at http://localhost:%s\n", port)
    log.Fatal(http.ListenAndServe(":" + port, nil))
}

func generateHandler(w http.ResponseWriter, r *http.Request) {
    ctx := context.Background()
    
    apiKey := os.Getenv("GEMINI_API_KEY")
    if apiKey == "" {
        data := PageData{
            Error: "GEMINI_API_KEY is not set",
        }
        w.Header().Set("Content-Type", "application/json")
        if err := json.NewEncoder(w).Encode(data); err != nil {
            log.Printf("Error encoding response: %v", err)
            http.Error(w, "Failed to send response", http.StatusInternalServerError)
        }
        return
    }

    client, err := genai.NewClient(ctx, option.WithAPIKey(apiKey))
    if err != nil {
        log.Printf("Error creating genai client: %v", err)
        http.Error(w, "Failed to create genai client", http.StatusInternalServerError)
        return
    }
    defer client.Close()

    var reqData struct {
        Prompt string `json:"prompt"`
    }
    if err := json.NewDecoder(r.Body).Decode(&reqData); err != nil {
        log.Printf("Error decoding request body: %v", err)
        http.Error(w, "Invalid request payload", http.StatusBadRequest)
        return
    }

    model := client.GenerativeModel("gemini-pro")
    resp, err := model.GenerateContent(ctx, genai.Text(reqData.Prompt))
    if err != nil {
        log.Printf("Error generating content: %v", err)
        http.Error(w, "Failed to generate content", http.StatusInternalServerError)
        return
    }

    // Extract the response text directly from the response structure
    var responseText string
    if len(resp.Candidates) > 0 && len(resp.Candidates[0].Content.Parts) > 0 {
        responseTextBytes, _ := json.Marshal(resp.Candidates[0].Content.Parts[0])
        responseText = string(responseTextBytes)
        fmt.Printf("%s\n", responseText)
    }

    data := PageData{
        Response: responseText,
    }
    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(data); err != nil {
        log.Printf("Error encoding response: %v", err)
        http.Error(w, "Failed to send response", http.StatusInternalServerError)
    }
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
    info := struct {
        Version string `json:"version"`
    }{
        Version: "0.5.0",
    }
    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(info); err != nil {
        log.Printf("Error encoding response: %v", err)
        http.Error(w, "Failed to send response", http.StatusInternalServerError)
    }
}

func helpHandler(w http.ResponseWriter, r *http.Request) {
    help := struct {
        Author string `json:"author"`
    }{
        Author: "AndyWang",
    }
    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(help); err != nil {
        log.Printf("Error encoding response: %v", err)
        http.Error(w, "Failed to send response", http.StatusInternalServerError)
    }
}

