import { start } from "node:repl";
import app from "./app";
import { config } from "./config";
import connectDB from "./config/db";

async function startServer() {
    const PORT = config.port ; 

    try{
        await connectDB().then(() => {
            app.listen(PORT, () => {
                console.log(`Server is running on port ${PORT}`);
            });
        });
    }
    catch(err){
        console.error(`Error: ${(err as Error).message}`);
        process.exit(1);
    }
        

}

 startServer();