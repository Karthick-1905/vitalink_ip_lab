import mongoose from "mongoose";
import logger from '@alias/utils/logger'
import { config } from '@alias/config'

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(config.databaseUrl);
    logger.info(`MongoDB Connected: ${conn.connection.host}`);
  }
  catch (err) {
    logger.error(`Error: ${(err as Error).message}`);
    process.exit(1);
  }
}
export default connectDB;
