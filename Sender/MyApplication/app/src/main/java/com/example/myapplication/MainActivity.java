package com.example.myapplication;
import android.content.Context;
import android.os.Bundle;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.util.Log;
import android.widget.Toast;
import android.media.AudioTrack;
import android.media.AudioFormat;
import android.media.AudioManager;
import androidx.appcompat.app.AppCompatActivity;
import com.google.android.material.textfield.TextInputEditText;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Objects;

public class MainActivity extends AppCompatActivity {

    private Vibrator vibrator;
    private TextInputEditText inputText;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Set up the content view to reference the fragment
        setContentView(R.layout.activity_main);


        // Initialize the vibrator
        vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        if (vibrator != null && vibrator.hasAmplitudeControl()) {
            Log.d("VIBRATOR", "Amplitude control available.");
        }
    }

    public String getInputText(){
        // Find the EditText and Button by their IDs
        inputText = findViewById(R.id.typedText);
        // Get the typed text from the EditText
        return  Objects.requireNonNull(inputText.getText()).toString();

    }
    //OOK modulation
    // public void startVibration(String text) {
    //     if (vibrator != null) {
    //         Log.d("VIBRATOR","availablevib");

    //         long[] pattern =generateVibrationPattern(text); // Vibration pattern[silence, vibration, silence, vibration,...]
    //         Log.d("pattern", Arrays.toString(pattern));

    //         int[] amplitudes = new int[pattern.length];
    //         for (int i = 0; i < pattern.length; i++) {
    //             // Alternate between 0 and 50
    //             amplitudes[i] = (i % 2 == 0) ? 0 : 100;
    //         }
    //         Log.d("amplitudes",Arrays.toString(amplitudes));
    //         vibrator.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, -1));
    //     }
    // }

    // OOK modulation - fixed vibration pattern, max amplitude
    // @SuppressWarnings("deprecation")
    // public void startVibration(String text) {
    //     if (vibrator != null) {
    //         Log.d("VIBRATOR", "availablevib");

    //         Fixed vibration pattern: [delay, vibrate, silence, vibrate, ...]
    //         Example: wait 0ms, vibrate 200ms, pause 100ms, vibrate 200ms, pause 100ms
    //         long[] pattern = {5000, 200, 100, 200, 100, 200, 200, 100, 200, 200};

    //         Use old vibrate API (max amplitude by default)
    //         vibrator.vibrate(pattern, -1);  // -1 means no repeat

    //         Log.d("pattern", Arrays.toString(pattern));
    //     }
    // }


//     private long[] generateVibrationPattern(String text) {

//         //make this 8 bits
//         StringBuilder binaryPattern = new StringBuilder();

//         // Convert each character to 8-bit binary and append to the pattern
//         for (char c : text.toCharArray()) {
//             String binaryString = String.format("%8s", Integer.toBinaryString(c)).replace(' ', '0');
//             binaryPattern.append(binaryString);
//         }
//         StringBuilder encodedBinaryPattern = new StringBuilder();
//         String preamble = "10101010";
//         String encodedBinary = applyHamming74(binaryPattern.toString());
//         // Get the length of the encoded string and convert it to 8-bit binary
//         int length = encodedBinary.length();
//         Log.d("encodedBinary length", String.valueOf(length));
//         String lengthBinary = String.format("%8s", Integer.toBinaryString(length)).replace(' ', '0');
//         encodedBinaryPattern.append(preamble);
//         encodedBinaryPattern.append(lengthBinary);
//         encodedBinaryPattern.append(encodedBinary);
//         Log.d("HammingEncoded", String.valueOf(encodedBinaryPattern));


//         // Convert binary pattern to vibration pattern
//         ArrayList<Long> patternList = new ArrayList<>();
//         patternList.add(0L);
//         long binaryOne =0;
//         long binaryZero=0;

//         for (int i = 0; i <encodedBinaryPattern.length(); i++) {
//             char currentBit = encodedBinaryPattern.charAt(i);
//             if (currentBit == '1') {
//                 if(i > 0 && encodedBinaryPattern.charAt(i - 1) == '0'){
//                     patternList.add(binaryZero);
//                     binaryZero = 0;
//                 }
//                 binaryOne+=80;
//             }
//             if (currentBit == '0') {
//                 if(i > 0 && encodedBinaryPattern.charAt(i - 1) == '1'){
//                     patternList.add(binaryOne) ;
//                     binaryOne = 0;
//                 }
//                 binaryZero+=80;
//             }
//             if(i == encodedBinaryPattern.length()-1){
//                 patternList.add(binaryOne!=0?binaryOne:binaryZero);
//             }
//         }

// //         Convert ArrayList<Long> to long[] array
//         long[] pattern = new long[patternList.size()];
//         for (int i = 1; i < patternList.size(); i++) {
//             pattern[i] = patternList.get(i);
//         }
//         pattern[0]=5000;

//        // Show the typed text using a Toast message
//         Toast.makeText(MainActivity.this, "Typed Text: " + Arrays.toString(pattern), Toast.LENGTH_SHORT).show();

//         return pattern;
//     }


    //Uncomment this and comment generateVibrationPattern and startVibration functions above for amplitude modulation
   public void startVibration(String text) {
       if (vibrator != null) {
           Log.d("VIBRATOR", "Vibrator available");

           // Generate vibration pattern and amplitudes based on text
           VibrationPattern vibrationPattern = generateVibrationPattern(text);
           // Log the generated pattern and amplitudes
           Log.d("VIBRATION_PATTERN", "Timings: " + Arrays.toString(vibrationPattern.pattern));
           Log.d("VIBRATION_AMPLITUDES", "Amplitudes: " + Arrays.toString(vibrationPattern.amplitudes));

           // Vibrate using the generated pattern and amplitudes
           vibrator.vibrate(VibrationEffect.createWaveform(
                   vibrationPattern.pattern, vibrationPattern.amplitudes, -1
           ));
       }
   }
//amplitude modulation
   private VibrationPattern generateVibrationPattern(String text) {
       // Add preamble (1011)
       //make this 8 bits
       StringBuilder binaryPattern = new StringBuilder();

       // Convert each character to 7-bit binary and append to the pattern
       for (char c : text.toCharArray()) {
           String binaryString = String.format("%8s", Integer.toBinaryString(c)).replace(' ', '0');
           binaryPattern.append(binaryString);
       }
       String encodedBinary = applyHamming74(binaryPattern.toString());

       StringBuilder encodedBinaryPattern = new StringBuilder();
       String preamble = "10101010";
       // Get the length of the encoded string and convert it to 8-bit binary
       int length = encodedBinary.length();
       Log.d("encodedBinary length", String.valueOf(length));
       String lengthBinary = String.format("%8s", Integer.toBinaryString(length)).replace(' ', '0');
       String Amplitudes = "10110100";
       encodedBinaryPattern.append(preamble);
       encodedBinaryPattern.append(Amplitudes);
       encodedBinaryPattern.append(lengthBinary);

       encodedBinaryPattern.append(encodedBinary);
       Log.d("HammingEncoded", String.valueOf(encodedBinaryPattern));
       // Initialize vibration pattern and amplitude lists
       ArrayList<Long> patternList = new ArrayList<>();
       ArrayList<Integer> amplitudeList = new ArrayList<>();

       // Add initial delay (5000ms)
       patternList.add(5000L);
       amplitudeList.add(0);


       // Generate vibration timings and amplitudes based on binary pattern
       for (int i = 0; i < encodedBinaryPattern.length(); i += 2) {
           String bitPair = encodedBinaryPattern.substring(i, Math.min(i + 2, encodedBinaryPattern.length()));

           switch (bitPair) {
               case "00":
                   patternList.add(100L);  // 100ms duration
                   amplitudeList.add(60);   // 20 amplitude
                   break;

               case "01":
                   patternList.add(100L);  // 100ms duration
                   amplitudeList.add(110);  // 40 amplitude
                   break;

               case "11":
                   patternList.add(100L);  // 100ms duration
                   amplitudeList.add(160);  // 60 amplitude
                   break;

               case "10":
                   patternList.add(100L);  // 100ms duration
                   amplitudeList.add(210);  // 80 amplitude
                   break;
           }

           // Add a silent interval between vibrations (100ms)
           patternList.add(50L); //50L
           amplitudeList.add(0);
           patternList.add(50L); //50L
           amplitudeList.add(0);
       }

       // Convert lists to arrays
       long[] pattern = new long[patternList.size()];
       int[] amplitudes = new int[amplitudeList.size()];

       for (int i = 0; i < patternList.size(); i++) {
           pattern[i] = patternList.get(i);
           amplitudes[i] = amplitudeList.get(i);
       }
       Toast.makeText(MainActivity.this, "Typed Text: " + Arrays.toString(pattern) + "amplitude " + Arrays.toString(amplitudes), Toast.LENGTH_SHORT).show();

       // Return both pattern and amplitudes
       return new VibrationPattern(pattern, amplitudes);
   }

   // Helper class to hold vibration pattern and amplitudes
   private static class VibrationPattern {
       long[] pattern;
       int[] amplitudes;

       VibrationPattern(long[] pattern, int[] amplitudes) {
           this.pattern = pattern;
           this.amplitudes = amplitudes;
       }
   }

    private String applyHamming74(String binaryString) {
        StringBuilder encodedString = new StringBuilder();

        // Process each 4-bit chunk separately
        for (int i = 0; i < binaryString.length(); i += 4) {
            String chunk = binaryString.substring(i, Math.min(i + 4, binaryString.length()));
            while (chunk.length() < 4) {
                chunk += "0"; // Pad with zeros if needed
            }
            encodedString.append(encodeHamming74(chunk));
        }
        return encodedString.toString();
    }

    private String encodeHamming74(String data) {
        int[] d = new int[4];
        int[] h = new int[7];

        for (int i = 0; i < 4; i++) {
            d[i] = data.charAt(i) - '0';
        }

        // Assign data bits to appropriate positions
        h[2] = d[0];
        h[4] = d[1];
        h[5] = d[2];
        h[6] = d[3];

        // Compute parity bits
        h[0] = d[0] ^ d[1] ^ d[3]; // p1
        h[1] = d[0] ^ d[2] ^ d[3]; // p2
        h[3] = d[1] ^ d[2] ^ d[3]; // p3

        // Convert to binary string
        StringBuilder encoded = new StringBuilder();
        for (int bit : h) {
            encoded.append(bit);
        }
        return encoded.toString();
    }


}

