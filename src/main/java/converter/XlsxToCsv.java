package converter;


import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;

import org.apache.poi.hssf.extractor.ExcelExtractor;
import org.apache.poi.hssf.usermodel.HSSFWorkbook;
import org.apache.poi.poifs.filesystem.POIFSFileSystem;

public class XlsxToCsv {

    public void convert(File inputFile, File outputFile) {
        InputStream inp = null;
        try {
            inp = new FileInputStream(inputFile);
        } catch (FileNotFoundException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        HSSFWorkbook wb = null;
        try {
            wb = new HSSFWorkbook(new POIFSFileSystem(inp));
        } catch (IOException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        ExcelExtractor extractor = new ExcelExtractor(wb);

        
        extractor.setFormulasNotResults(true);
        extractor.setIncludeSheetNames(false);
        String text = extractor.getText();
        PrintStream ps = null;
        try {
            ps = new PrintStream(outputFile);
        } catch (FileNotFoundException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        ps.print(text);
        
    }

}