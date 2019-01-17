
import static java.util.Arrays.sort;

import java.lang.reflect.Field;

public class Test {

     static String a = "dd";
     private String phonenum;

     public String c;
     public String getPhonenum() {
         return this.phonenum;
     }

     public void setPhonenum(String phonenum) {
     this.phonenum = phonenum;
     }

    static {
        System.out.println("Class initilized");
        System.out.println("rrrrr");
    }

    public static void main (String[] args)
    {
        try {
            System.out.println(Class.forName("Test").getDeclaredField("phonenum").getName());
        } catch (NoSuchFieldException | SecurityException | ClassNotFoundException e1 ) {
            e1.printStackTrace();
        }
        sort(new int[]{1,2,3,4,5});
        for (Field field: Test.class.getFields()) {
            System.out.println(field.getName());
        }
         System.out.println("rrrrr");
         System.out.println("1");
    }
}
