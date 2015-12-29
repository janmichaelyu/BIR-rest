import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.util.Collection;
import java.util.Iterator;

import org.apache.commons.io.FileUtils;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.poi.poifs.filesystem.POIFSFileSystem;
import org.apache.tika.exception.TikaException;
import org.apache.tika.metadata.Metadata;
import org.apache.tika.parser.AutoDetectParser;
import org.apache.tika.sax.ToXMLContentHandler;
import org.xml.sax.SAXException;

import converter.XlsxToCsv;
import example.poi.apache.XLS2CSVmra;

public class Main {
    private static final String XML              = ".xml";
    private static final String XLSX             = "xlsx";
    private static final String SEP              = "/";
    private static final String CSV              = ".csv";
    private static final String XLS              = "xls";
    private static final int    NO_MINIMUM       = -1;
    private static final String OUTPUT_DIRECTORY = "output";
    private static final String DATA_DIRECTORY   = "data/final";
    private static final Logger logger           = LogManager
                                                         .getLogger(Main.class);

    public static void main(String[] args) {
        logger.info("START");
        File dataDir = new File(DATA_DIRECTORY);
        if (dataDir.exists()) {

            File outputDirectory = processOutputDirectory();

            Collection<File> listFiles = FileUtils.listFiles(dataDir,
                    new String[] { XLS, XLSX }, true);
            Iterator<File> listFilesIterator = listFiles.iterator();

            while (listFilesIterator.hasNext()) {
                File inputFile = listFilesIterator.next();
                PrintStream ps = null;
                try {
                    ToXMLContentHandler handler = new ToXMLContentHandler();

                    AutoDetectParser parser = new AutoDetectParser();
                    Metadata metadata = new Metadata();

                    InputStream stream = new FileInputStream(inputFile);
                    parser.parse(stream, handler, metadata);

                    File outputXml = getOutputFileXml(inputFile,
                            outputDirectory);
                    if (outputXml.exists()) {
                        outputXml.delete();
                    }

                    ps = new PrintStream(outputXml);

                    ps.print(handler.toString());
                } catch (Exception e) {
                    logger.error(e);
                } finally {
                    if (ps != null) {
                        ps.close();
                    }
                }

                // if (inputFile.getName().endsWith(XLS)) {
                // extractXsl(inputFile, outputDirectory);
                // } else if (inputFile.getName().endsWith(XLSX)) {
                // logger.info(inputFile.getName());
                // extractXslx(inputFile, outputDirectory);
                // } else {
                // logger.error("Invalid file found in list.");
                // }
            }

        } else {
            logger.error("Data dir {} does not exist.", DATA_DIRECTORY);
        }

        logger.info("END");
    }

    private static File getOutputFileXml(File inputFile, File outputDirectory) {
        File outputFile = new File(outputDirectory.getAbsolutePath() + SEP
                + inputFile.getName() + XML);
        return outputFile;
    }

    private static void extractXslx(File inputFile, File outputDirectory) {
        // TODO Auto-generated method stub
        // ToCSV converter = new ToCSV();
        // converter.convertExcelToCSV(strSource, strDestination);
    }

    private static void extract(File inputFile, File outputDirectory) {
        XlsxToCsv converter = new XlsxToCsv();
        File outputCsv = getOutputFileCsv(inputFile, outputDirectory);
        converter.convert(inputFile, outputCsv);
    }

    private static File getOutputFileCsv(File inputFile, File outputDirectory) {
        File outputCsv = new File(outputDirectory.getAbsolutePath() + SEP
                + inputFile.getName() + CSV);
        return outputCsv;
    }

    private static void extractXsl(File inputFile, File outputDirectory) {
        try {
            File outputCsv = getOutputFileCsv(inputFile, outputDirectory);
            if (outputCsv.exists()) {
                outputCsv.delete();
            }
            FileOutputStream fos = new FileOutputStream(outputCsv, true);
            PrintStream printStream = new PrintStream(fos);

            XLS2CSVmra extractor = new XLS2CSVmra(new POIFSFileSystem(
                    new FileInputStream(inputFile.getAbsolutePath())),
                    printStream, NO_MINIMUM);
            extractor.process();
        } catch (FileNotFoundException e) {
            logger.error(e);
        } catch (IOException e) {
            logger.error(e);
        }
    }

    private static File processOutputDirectory() {
        File outputDirectory = new File(OUTPUT_DIRECTORY);
        if (!outputDirectory.exists()) {
            outputDirectory.mkdir();
        }

        return outputDirectory;
    }

}
