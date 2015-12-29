import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.util.Collection;
import java.util.Iterator;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.filefilter.DirectoryFileFilter;
import org.apache.commons.io.filefilter.NotFileFilter;
import org.apache.commons.io.filefilter.TrueFileFilter;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.poi.openxml4j.exceptions.InvalidFormatException;
import org.apache.poi.poifs.filesystem.POIFSFileSystem;

import converter.XlsxToCsv;
import example.poi.apache.ToCSV;
import example.poi.apache.XLS2CSVmra;

public class Convert {
    private static final String OUTPUT_DIRECTORY = "output";
    private static final String DATA_DIRECTORY   = "data/final";
    private static final Logger logger           = LogManager
                                                         .getLogger(Convert.class);

    public static void main(String[] args) {
        logger.info("START");
        File dataDir = new File(DATA_DIRECTORY);
        if (dataDir.exists()) {

            File outputDirectory = processOutputDirectory();

            Collection<File> listDirs = FileUtils.listFilesAndDirs(dataDir,
                    new NotFileFilter(TrueFileFilter.INSTANCE),
                    DirectoryFileFilter.DIRECTORY);

            Iterator<File> listDirsIterator = listDirs.iterator();
            while (listDirsIterator.hasNext()) {
                File inputDir = listDirsIterator.next();
                ToCSV converter = new ToCSV();
                try {
                    converter.convertExcelToCSV(inputDir.getAbsolutePath(),
                            outputDirectory.getAbsolutePath());
                } catch (Exception e) {
                    logger.error(e);
                }

            }

        } else {
            logger.error("Data dir {} does not exist.", DATA_DIRECTORY);
        }

        logger.info("END");
    }

    private static File processOutputDirectory() {
        File outputDirectory = new File(OUTPUT_DIRECTORY);
        if (!outputDirectory.exists()) {
            outputDirectory.mkdir();
        }

        return outputDirectory;
    }
}
