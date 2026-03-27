import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bingo/utils/colors.dart';
import 'package:intl/intl.dart';

class MatchHistoryPage extends StatelessWidget {
  const MatchHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: netflixBlack,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "MATCH HISTORY",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 16,
            color: netflixRed,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(color: netflixBlack),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.2),
                  radius: 1.5,
                  colors: [netflixRed.withOpacity(0.1), Colors.transparent],
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth > 700;
              final double horizontalPadding = isTablet ? constraints.maxWidth * 0.2 : 24;
              final double listMaxWidth = isTablet ? 700 : 500;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('match_history')
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: netflixRed));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, color: Colors.white12, size: 80),
                          const SizedBox(height: 16),
                          Text(
                            "NO MATCHES YET",
                            style: GoogleFonts.poppins(
                              color: Colors.white24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: listMaxWidth),
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(horizontalPadding, 120, horizontalPadding, 24),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          final winnerName = data['winnerName'] ?? "Unknown";
                          final winnerId = data['winnerId'] ?? "";
                          final winMode = data['winMode'] ?? "Classic";
                          final timestamp = data['timestamp'] as Timestamp?;
                          final dateStr = timestamp != null 
                              ? DateFormat('MMM dd, HH:mm').format(timestamp.toDate())
                              : "Recently";

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: netflixGrey.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: netflixRed.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      "https://api.dicebear.com/7.x/avataaars/svg?seed=${data['avatarSeed'] ?? winnerId}",
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, color: netflixRed),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        winnerName.toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        "WON: $winMode",
                                        style: GoogleFonts.poppins(
                                          color: netflixRed,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  dateStr,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white38,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
