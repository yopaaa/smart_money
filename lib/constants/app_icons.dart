import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class AppIcons {
  static IconData getIcon(String? name) {
    if (name == null || name.isEmpty) return Ionicons.shapesOutline;

    switch (name.toLowerCase()) {
      // Account types
      case 'cash':
      case 'cash-plus':
        return Ionicons.cashOutline;
      case 'account-cash':
        return Ionicons.walletOutline;
      case 'card':
      case 'credit-card':
      case 'credit-card-outline':
      case 'debit':
        return Ionicons.cardOutline;
      case 'saving':
      case 'bank':
        return Ionicons.businessOutline;
      case 'invest':
      case 'chart-line':
        return Ionicons.trendingUpOutline;
      case 'liability':
      case 'file-document':
        return Ionicons.documentTextOutline;
      case 'debt':
        return Ionicons.peopleOutline;
      case 'receivable':
      case 'account-arrow-left':
        return Ionicons.personAddOutline;
      case 'expense-buffer':
      case 'umbrella':
        return Ionicons.umbrellaOutline;
      case 'wallet':
      case 'wallet-giftcard':
        return Ionicons.walletOutline;

      // Expenses categories
      case 'silverware-fork-knife':
      case 'food':
        return Ionicons.restaurantOutline;
      case 'cup-water':
      case 'drink':
        return Ionicons.cafeOutline;
      case 'bus':
      case 'transport':
      case 'car':
        return Ionicons.carOutline;
      case 'shopping':
      case 'cart':
        return Ionicons.cartOutline;
      case 'movie':
      case 'film':
        return Ionicons.filmOutline;
      case 'heart-pulse':
      case 'health':
        return Ionicons.heartOutline;
      case 'school':
      case 'education':
        return Ionicons.schoolOutline;
      case 'hand-heart':
      case 'donate':
        return Ionicons.heartCircleOutline;
      case 'bank-transfer-out':
        return Ionicons.arrowUpCircleOutline;
      case 'bank-transfer-in':
        return Ionicons.arrowDownCircleOutline;
      case 'bank-transfer':
      case 'transfer':
        return Ionicons.swapHorizontalOutline;
      case 'file-cog':
      case 'admin':
        return Ionicons.constructOutline;
      case 'gift':
      case 'party-popper':
        return Ionicons.giftOutline;
      case 'cellphone':
      case 'phone':
        return Ionicons.phonePortraitOutline;
      case 'home':
        return Ionicons.homeOutline;
      case 'face-woman':
      case 'skincare':
        return Ionicons.sparklesOutline;
      case 'piggy-bank':
      case 'savings':
        return Ionicons.walletOutline;
      case 'briefcase':
      case 'work':
        return Ionicons.briefcaseOutline;
      case 'safe':
      case 'vault':
        return Ionicons.lockClosedOutline;
      case 'hand-coin':
      case 'currency-usd':
        return Ionicons.cashOutline;
      case 'store':
        return Ionicons.storefrontOutline;
      case 'calendar-month':
        return Ionicons.calendarOutline;
      case 'account-circle':
        return Ionicons.personCircleOutline;
      case 'dots-horizontal':
      case 'other':
      default:
        return Ionicons.ellipsisHorizontal;
    }
  }
}
